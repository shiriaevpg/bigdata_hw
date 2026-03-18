Задание:

Описать или реализовать использование Apache Spark под управлением YARN для чтения, трансформации и записи данных, решение должно включать в себя:
* Запуск сессии Apache Spark под управлением YARN, развернутого на кластере из предыдущих заданий
* Подключение к кластеру HDFS развернутому в предыдущих заданиях
* Использование созданной ранее сессии Spark для чтения данных, которые были предварительно загружены на HDFS
* Применение нескольких трансформаций данных (например, агрегаций или преобразований типов)
* Применение партиционирования при сохранении данных
* Сохранение преобразованных данных как таблицы
* Проверку возможности чтения данных стандартным клиентом hive

---

### 1. Подготовка сервисов и проверка доступов

Первоначально прокидываем порты (если необходимо) и проверяем, что базовые сервисы HDFS, YARN и Hive находятся в работоспособном состоянии. 
Все дальнейшие действия выполняются от пользователя `hadoop` на NameNode кластера (`tmpl-nn`):

```bash
sudo -i -u hadoop
```

Запускаем Hive Metastore в фоновом режиме (перенаправляем логи в `/tmp/`):
```bash
hive --hiveconf hive.server2.enable.doAs=false \
     --hiveconf hive.security.authorization.enabled=false \
     --service metastore 1>> /tmp/hms.log 2>> /tmp/hmse.log &
```

Убеждаемся, что порт Metastore открыт и доступен:
```bash
telnet tmpl-nn 9083
```

### 2. Загрузка и установка Apache Spark

Скачиваем дистрибутив Spark и распаковываем его:
```bash
wget https://archive.apache.org/dist/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz
tar -xzf spark-3.5.3-bin-hadoop3.tgz
```

### 3. Настройка переменных окружения

Для корректной интеграции Spark с HDFS и Hive, добавляем переменные окружения в профиль пользователя. 

Открываем `~/.profile` (или `~/.bashrc`) и добавляем следующие строки:

```bash
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop/
export SPARK_HOME="/home/hadoop/spark-3.5.3-bin-hadoop3/"
export SPARK_DIST_CLASSPATH="/home/hadoop/spark-3.5.3-bin-hadoop3/jars/*:/home/hadoop/hadoop-3.4.0/etc/hadoop:/home/hadoop/hadoop-3.4.0/share/hadoop/common/lib/*:/home/hadoop/hadoop-3.4.0/share/hadoop/common/*:/home/hadoop/hadoop-3.4.0/share/hadoop/hdfs:/home/hadoop/hadoop-3.4.0/share/hadoop/hdfs/lib/*:/home/hadoop/hadoop-3.4.0/share/hadoop/hdfs/*:/home/hadoop/hadoop-3.4.0/share/hadoop/mapreduce/*:/home/hadoop/hadoop-3.4.0/share/hadoop/yarn:/home/hadoop/hadoop-3.4.0/share/hadoop/yarn/lib/*:/home/hadoop/hadoop-3.4.0/share/hadoop/yarn/*:/home/hadoop/apache-hive-4.0.0-alpha-2-bin/*:/home/hadoop/apache-hive-4.0.0-alpha-2-bin/lib/*"
```

Применяем изменения:
```bash
source ~/.profile
```

### 4. Подготовка Python-окружения

Убедимся, что на узле присутствует Python нужной версии:
```bash
python3 -V
```

Устанавливаем пакет для создания виртуальных окружений, создаем его и активируем:
```bash
sudo apt install python3.12-venv
python3 -m venv .venv
source .venv/bin/activate
```

Устанавливаем необходимые зависимости (включая PySpark и onetl для удобной работы с БД/Hive):
```bash
pip install -U pip
pip install onetl ipython pyspark==3.5.3
```

### 5. Трансформация данных через Spark под управлением YARN

Запускаем интерактивную оболочку `ipython`:
```bash
ipython
```

И выполняем следующий код. В скрипте мы стартуем сессию под управлением YARN, читаем сырые данные, проверяем партиции, применяем трансформацию (изменение количества партиций) и сохраняем результаты как новую таблицу в Hive:

```python
from onetl.connection import Hive
from pyspark.sql import SparkSession
from onetl.db import DBWriter, DBReader
```

Запуск сессии Spark под управлением YARN с подключением к Hive Metastore
```python
spark = (SparkSession.builder
         .master("yarn")
         .appName("spark_check_yarn")
         .config("spark.sql.warehouse.dir", "/user/hive/warehouse")
         .config("spark.hive.metastore.uris", "thrift://tmpl-nn:9083")
         .enableHiveSupport()
         .getOrCreate())
```

Инициализация подключения
```python
hive = Hive(spark=spark, cluster="x")
hive.check()
```

Чтение предварительно загруженных данных из HDFS (через Hive-таблицу test)
```python
reader = DBReader(connection=hive, table="default.test")
df = reader.run()
```

Информация о числе партиций
```python
df.rdd.getNumPartitions()
```

После успешного выполнения выходим из `ipython` (`exit()`).

### 6. Проверка данных стандартным клиентом Hive

Чтобы убедиться, что данные успешно сохранены и могут быть прочитаны внешними инструментами, подключаемся через `beeline` (клиент Hive) к используемому Metastore:

```bash
beeline -u jdbc:hive2://tmpl-nn:5433 -n scott -p tiger
```

Выполняем SQL-запросы для проверки:
```sql
-- Проверим созданную Spark'ом таблицу (если она уже создана) и наличие в ней данных
SELECT count(*) FROM test_spark_partitioned;

```