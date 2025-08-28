FROM alpine:latest

WORKDIR /wsk

COPY red_1.0.0 .

RUN apk --no-cache add curl

RUN chmod +x ./red_1.0.0

CMD ["./red_1.0.0"]