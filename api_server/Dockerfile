# Stage 1: Build
FROM rust:1.75-slim AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

# Stage 2: Run
FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/target/release/api_server .
EXPOSE 5000
CMD ["./api_server"]
