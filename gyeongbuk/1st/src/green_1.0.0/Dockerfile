FROM public.ecr.aws/docker/library/alpine:3.21.3

WORKDIR /app

COPY green_1.0.0 .

RUN apk --no-cache add curl

RUN chmod +x ./green_1.0.0

CMD ["./green_1.0.0"]