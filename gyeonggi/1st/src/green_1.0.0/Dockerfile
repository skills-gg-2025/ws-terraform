FROM public.ecr.aws/docker/library/alpine

WORKDIR /app

COPY green_1.0.0 .

RUN apk --no-cache add curl

CMD ["./green_1.0.0"]