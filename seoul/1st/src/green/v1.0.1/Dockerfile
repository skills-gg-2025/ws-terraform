FROM alpine:latest

WORKDIR /wsk

COPY green_1.0.1 .

RUN apk --no-cache add curl

RUN chmod +x ./green_1.0.1

CMD ["./green_1.0.1"]