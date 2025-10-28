FROM nginx:1.25-alpine

# Remove the default nginx page
RUN rm /usr/share/nginx/html/index.html

COPY ./html/health.txt /usr/share/nginx/html/health.txt