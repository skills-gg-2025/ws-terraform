FROM alpine:latest

WORKDIR /wsk

COPY red_1.0.1 .

RUN apk --no-cache add curl

RUN chmod +x ./red_1.0.1

CMD ["./red_1.0.1"]