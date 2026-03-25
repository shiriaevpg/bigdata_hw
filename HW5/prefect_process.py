from prefect import flow, task
from prefect.cache_policies import NO_CACHE

from onetl.db import DBWriter
from onetl.connection import Hive, SparkHDFS
from onetl.file import FileDFReader
from onetl.file.format import Parquet

from pyspark.sql import functions as F
from pyspark.sql import SparkSession


@task(cache_policy=NO_CACHE)
def start_spark():
    spark = (
        SparkSession.builder
        .master("yarn")
        .appName("spark_from_prefect")
        .config("spark.sql.warehouse.dir", "/user/hive/warehouse")
        .config("spark.hive.metastore.uris", "thrift://tmpl-nn:9083")
        .enableHiveSupport()
        .getOrCreate()
    )
    return spark


@task(cache_policy=NO_CACHE)
def stop_spark(spark):
    spark.stop()


@task(cache_policy=NO_CACHE)
def extract(spark):
    hdfs = SparkHDFS(
        host="tmpl-nn",
        port=9000,
        spark=spark,
        cluster="x"
    )

    reader = FileDFReader(
        connection=hdfs,
        format=Parquet(),
        source_path="/raw"
    )

    df = reader.run(["test.zstd.parquet"])
    return df


@task(cache_policy=NO_CACHE)
def transform(spark, df):
    hive = Hive(spark=spark, cluster="x")

    df = df.select("*")  # TODO выбрать нужные
    df = df.withColumn("dow_str", F.col("date_dow").cast("string"))

    return hive, df


@task(cache_policy=NO_CACHE)
def load(hive, df):
    writer = DBWriter(
        connection=hive,
        target="default.test_prefect_partitioned",
        options={
            "if_exists": "replace_entire_table",
            "partitionBy": "dow_str"
        }
    )

    writer.run(df)


@flow
def process_data():
    spark = start_spark()

    df = extract(spark)
    hive, df = transform(spark, df)

    load(hive, df)

    stop_spark(spark)


if __name__ == "__main__":
    process_data()

