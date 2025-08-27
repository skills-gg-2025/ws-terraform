FROM public.ecr.aws/docker/library/alpine:3.21.3

WORKDIR /app

COPY red_1.0.0 .

RUN apk --no-cache add curl

RUN chmod +x ./red_1.0.0

CMD ["./red_1.0.0"]