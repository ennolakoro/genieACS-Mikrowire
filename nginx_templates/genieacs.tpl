# genieacs.tpl
# HestiaCP Nginx template for Multi-Tenant GenieACS (HTTP)

server {
    listen      %ip%:%web_port%;
    server_name %domain% %alias%;

    # Redirect all HTTP requests to HTTPS (standard secure setup)
    # If a client does not have SSL enabled yet, this template will include their HTTP proxy setup.
    include %home%/%user%/conf/web/%domain%/nginx.genieacs_proxy.conf*;

    # Fallback logging
    access_log  /var/log/nginx/domains/%domain%.log combined;
    access_log  /var/log/nginx/domains/%domain%.bytes bytes;
    error_log   /var/log/nginx/domains/%domain%.error.log error;
}
