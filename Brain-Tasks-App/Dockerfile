# ─────────────────────────────────────────────
# Stage 1: Serve the pre-built dist with Nginx
# ─────────────────────────────────────────────
FROM nginx:1.25-alpine

LABEL maintainer="devops@braintasks.app"
LABEL app="brain-tasks-app"
LABEL version="1.0.0"

# Remove the default Nginx welcome page
RUN rm -rf /usr/share/nginx/html/*

# Copy production build from dist/
COPY dist/ /usr/share/nginx/html/

# Copy custom Nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 3000 (as required)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000 || exit 1

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
