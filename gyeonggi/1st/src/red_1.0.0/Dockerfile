FROM public.ecr.aws/docker/library/alpine

WORKDIR /app

COPY red_1.0.0 .

RUN chmod +x ./red_1.0.0

RUN apk --no-cache add curl

CMD ["./red_1.0.0"]