# swagger 전용 도커 이미지
FROM swaggerapi/swagger-ui:v5.31.0
COPY swagger-config.json /usr/share/nginx/html/swagger-config.json
ENV CONFIG_URL=/swagger-config.json
