FROM public.ecr.aws/docker/library/alpine

WORKDIR /app

COPY green .

RUN chmod +x ./green

RUN apk --no-cache add curl

CMD ["./green"]