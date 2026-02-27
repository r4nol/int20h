# INT20H Hackathon — Online Boutique Cartservice
#
# This Dockerfile re-packages the upstream Google microservices-demo cartservice
# image under the project's GHCR namespace so the CI/CD pipeline can:
#   1. Build a versioned, labeled image with BuildKit (multi-arch: amd64 + arm64)
#   2. Scan it with Trivy and report results to GitHub Security tab
#   3. Push to GHCR with a commit-SHA tag (main-<sha>)
#   4. Have ArgoCD deploy the new tag via kustomize image override
#
# Cartservice: Go gRPC service + Redis client for shopping cart management
# Original source: https://github.com/GoogleCloudPlatform/microservices-demo/tree/main/src/cartservice

FROM gcr.io/google-samples/microservices-demo/cartservice:v0.10.0

# Metadata labels (OCI standard)
LABEL org.opencontainers.image.source="https://github.com/r4nol/int20h"
LABEL org.opencontainers.image.description="Online Boutique Cartservice — INT20H Hackathon"
LABEL org.opencontainers.image.vendor="INT20H Team"
LABEL org.opencontainers.image.licenses="Apache-2.0"
