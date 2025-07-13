# Studio Notebook
현재 Terraform에서 Flink Studio Notebook에 대한 지원이 없는 상황입니다. 따라서 노트북은 수동적으로 생성합니다.
입력해야 하는 SQL은 다음과 같습니다.

```sql
%flink.ssql
CREATE TABLE input_table (
    level VARCHAR(5),
    `method` VARCHAR(6),
    path VARCHAR(10),
    status_code VARCHAR(3),
    event_time TIMESTAMP(0),
    WATERMARK FOR event_time AS event_time - INTERVAL '1' SECOND
)
WITH (
    'connector' = 'kinesis',
    'stream' = 'input-stream',
    'aws.region' = 'ap-southeast-1',
    'scan.stream.initpos' = 'LATEST',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);
```

```sql
%flink.ssql
CREATE TABLE output_table (
    level VARCHAR(5),
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    counts BIGINT
)
WITH (
    'connector' = 'kinesis',
    'stream' = 'output-stream',
    'aws.region' = 'ap-southeast-1',
    'sink.partitioner' = 'random',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);
```

```sql
%flink.ssql
INSERT INTO output_table
SELECT level, window_start, window_end, count(*) AS counts
FROM TABLE(CUMULATE(TABLE input_table, DESCRIPTOR(event_time), INTERVAL '10' SECONDS, INTERVAL '30' SECONDS))
GROUP BY level, window_start, window_end;
```