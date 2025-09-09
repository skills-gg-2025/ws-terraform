FROM public.ecr.aws/docker/library/alpine

WORKDIR /app

COPY red .

RUN chmod +x ./red

RUN apk --no-cache add curl

CMD ["./red"]