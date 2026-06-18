# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development, and is meant
# to run standalone from nothing but environment variables — no deploy tool
# (Kamal or otherwise) required:
#
#   docker build -t chore-reminder .
#   docker run -d -p 80:80 \
#     -e SECRET_KEY_BASE=<output of: bin/rails secret> \
#     -e DATABASE_HOST=... -e DATABASE_USERNAME=... -e DATABASE_PASSWORD=... -e DATABASE_NAME=... \
#     -e TWILIO_ACCOUNT_SID=... -e TWILIO_AUTH_TOKEN=... -e TWILIO_FROM_NUMBER=... \
#     -e APP_HOST=... \
#     --name chore-reminder philmonroe/chore-reminder
#
# The Solid Queue worker runs from the same image — override the command:
#
#   docker run -d \
#     -e SECRET_KEY_BASE=... -e DATABASE_HOST=... [...same env as above] \
#     --name chore-reminder-worker philmonroe/chore-reminder bin/jobs
#
# See README.md for the full list of environment variables.
#
# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages. The apt cache is mounted rather than removed so
# repeated builds (locally, or across CI runs once the GitHub Actions cache
# warms up) don't redownload the same .debs every time.
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config

# Distinguish the bundle cache by architecture: this stage builds for
# multiple platforms (see .github/workflows/docker-publish.yml), and native
# extensions compiled for arm64 can't be reused on amd64 or vice versa.
ARG TARGETARCH

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

# The bundle cache is mounted at a separate path from BUNDLE_PATH, then
# copied into BUNDLE_PATH proper (a normal, committed layer) once install
# finishes. Gem downloads and, more importantly, compiled native extensions
# (nokogiri, pg, commonmarker, ...) persist in the mount across builds even
# when Gemfile.lock changes — a plain `RUN bundle install` layer would be
# fully invalidated and rebuilt from scratch by any lockfile change at all,
# however small. This always benefits local rebuilds; in CI it benefits
# whichever runs share a BuildKit cache backend/builder.
RUN --mount=type=cache,id=bundle-cache-${TARGETARCH},target=/usr/local/bundle-cache,sharing=locked \
    BUNDLE_PATH=/usr/local/bundle-cache bundle install && \
    mkdir -p "${BUNDLE_PATH}" && \
    cp -a /usr/local/bundle-cache/. "${BUNDLE_PATH}/" && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Build metadata, passed via --build-arg in CI (see
# .github/workflows/docker-publish.yml). Lets you confirm exactly which
# commit a running container was built from: `docker exec <container> env`.
ARG GIT_SHA=""
ARG GIT_REF=""
ARG GIT_COMMIT_MESSAGE=""
ENV GIT_SHA=${GIT_SHA} \
    GIT_REF=${GIT_REF} \
    GIT_COMMIT_MESSAGE=${GIT_COMMIT_MESSAGE}

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
