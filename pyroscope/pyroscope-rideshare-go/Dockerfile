# Stage 1: Build
FROM golang:1.21.8 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# 🔧 Properly set output binary path (no subdirectory)
RUN CGO_ENABLED=0 GOOS=linux go build -o /rideshare ./cmd/rideshare

# Stage 2: Minimal runtime
FROM alpine:3.20

RUN apk add --no-cache ca-certificates

# Copy built binary to image root
COPY --from=builder /rideshare /usr/local/bin/rideshare

ENTRYPOINT ["/usr/local/bin/rideshare"]


