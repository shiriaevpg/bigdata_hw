Задание:

Необходимо задокументировать или реализовать автоматизированное развертывание Apache Hive на существующем кластере Hadoop, настройку базы данных PostgreSQL в качестве Metastore и запуск сервиса HiveServer2.

### 1. Скачивание Apache Hive
Подключаемся к NameNode от пользователя `hadoop`:
```bash
ssh tmpl-nn
sudo -i -u hadoop
wget https://archive.apache.org/dist/hive/hive-4.0.0-alpha-2/apache-hive-4.0.0-alpha-2-bin.tar.gz
```
Копируем архив на JumpNode (если планируется дальнейшая работа с ним оттуда):
```bash
scp apache-hive-4.0.0-alpha-2-bin.tar.gz tmpl-jn:/home/hadoop
```
Выходим с NameNode (возвращаемся на ubuntu):
```bash
exit
```

### 2. Установка и настройка PostgreSQL для Metastore
Подключаемся к узлу DataNode-01, где будет развернута база данных:
```bash
ssh tmpl-dn-01
sudo apt update
sudo apt install -y postgresql 
```

Заходим под пользователем `postgres` и создаем базу данных с пользователем:
```bash
sudo -i -u postgres
psql
```
Выполняем SQL-команды:
```sql
CREATE DATABASE metastore;
CREATE USER hive with password 'hiveMegaPass';
GRANT ALL PRIVILEGES ON DATABASE "metastore" to hive;
ALTER DATABASE metastore OWNER TO hive;
\q
```
Выходим из пользователя `postgres`:
```bash
exit
```

Разрешаем внешние подключения к базе данных.
Открываем конфигурационный файл `postgresql.conf`:
```bash
sudo vim /etc/postgresql/16/main/postgresql.conf
```
Находим параметр `listen_addresses`, раскомментируем его и указываем имя текущего хоста:
```text
listen_addresses = 'tmpl-dn-01'
```

Открываем файл политик доступа `pg_hba.conf`:
```bash
sudo vim /etc/postgresql/16/main/pg_hba.conf
```
В секции `IPv4 local connections` комментируем существующие строки и добавляем доступ для пользователя `hive` с узлов `tmpl-jn` (JumpNode) и `tmpl-nn` (NameNode). IP-адреса указываем в соответствии с вашей сетью:
```text
host    metastore       hive            192.168.10.54/32        password
host    metastore       hive            192.168.10.22/32        password
```

Перезапускаем PostgreSQL для применения настроек:
```bash
sudo systemctl restart postgresql
```

Убеждаемся, что локальное подключение по IP отклоняется (проверка политик безопасности):
```bash
psql -h tmpl-dn-01 -p 5432 -U hive -W -d metastore
```

### 3. Проверка удаленного подключения к Metastore
На JumpNode (`tmpl-jn`) и NameNode (`tmpl-nn`) устанавливаем клиент PostgreSQL и проверяем подключение.

Для JumpNode:
```bash
sudo apt install -y postgresql-client-16
psql -h tmpl-dn-01 -p 5432 -U hive -W -d metastore
\q
```

Для NameNode:
```bash
ssh tmpl-nn
sudo apt install -y postgresql-client-16
psql -h tmpl-dn-01 -p 5432 -U hive -W -d metastore 
\q
exit
```
Подключение должно проходить успешно (потребуется ввести пароль `hiveMegaPass`).

### 4. Установка и базовая конфигурация Hive на NameNode
Подключаемся к NameNode под пользователем `hadoop`:
```bash
ssh tmpl-nn
sudo -i -u hadoop
```

Распаковываем архив и скачиваем JDBC-драйвер PostgreSQL в директорию `lib`:
```bash
tar -xzvf apache-hive-4.0.0-alpha-2-bin.tar.gz
cd apache-hive-4.0.0-alpha-2-bin/lib
wget https://jdbc.postgresql.org/download/postgresql-42.7.4.jar
```

Создаем и редактируем конфигурационный файл Hive:
```bash
cd ../conf
vim hive-site.xml
```
Вставляем следующую конфигурацию (обратите внимание на правильный URL базы данных):
```xml
<configuration>
        <property>
                <name>hive.server2.authentication</name>
                <value>NONE</value>
        </property>
        <property>
                <name>hive.metastore.warehouse.dir</name>
                <value>/user/hive/warehouse</value>
        </property>
        <property>
                <name>hive.server2.thrift.port</name>
                <value>5433</value>
                <description>TCP port number to listen on, default 10000</description>
        </property>
        <property>
                <name>javax.jdo.option.ConnectionURL</name>
                <value>jdbc:postgresql://tmpl-dn-01:5432/metastore</value>
        </property>
        <property>
                <name>javax.jdo.option.ConnectionDriverName</name>
                <value>org.postgresql.Driver</value>
        </property>
        <property>
                <name>javax.jdo.option.ConnectionUserName</name>
                <value>hive</value>
        </property>
        <property>
                <name>javax.jdo.option.ConnectionPassword</name>
                <value>hiveMegaPass</value>
        </property>
</configuration>
```

Добавляем переменные окружения Hive в `.profile`:
```bash
cd ~
vim .profile
```
Добавляем следующие строки:
```bash
export HIVE_HOME=/home/hadoop/apache-hive-4.0.0-alpha-2-bin
export HIVE_CONF_DIR=$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=$HIVE_HOME/lib/*
export PATH=$PATH:$HIVE_HOME/bin
```

Применяем изменения и проверяем версию Hive:
```bash
source .profile
hive --version
```

### 5. Подготовка HDFS и инициализация схемы Metastore
Создаем необходимые директории в пространстве HDFS и выдаем им права:
```bash
# Если директории уже есть, можно не создавать. С другой стороны, их выполнение не перезатрёт уже существующие
hdfs dfs -mkdir -p /tmp 
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod g+w /tmp
hdfs dfs -chmod g+w /user/hive/warehouse
```

Инициализируем схему базы данных Metastore через `schematool`:
```bash
cd apache-hive-4.0.0-alpha-2-bin
bin/schematool -dbType postgres -initSchema 
```

### 6. Запуск HiveServer2 и проверка
Запускаем сервис `hiveserver2` в фоновом режиме, перенаправляя логи:
```bash
hive --hiveconf hive.server2.enable.doAs=false --hiveconf hive.security.authorization.enabled=false --service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2e.log &
```

Проверяем, что процесс запущен:
```bash
jps
```
В выводе должен присутствовать процесс `RunJar`.

Подключаемся к Hive через утилиту `beeline` (обратите внимание, что подключение выполняется к узлу, где запущен HiveServer2 — в данном случае `tmpl-nn`):
```bash
beeline -u jdbc:hive2://tmpl-nn:5433 -n scott tiger
```
Для выхода из beeline введите:
```text
!q
```

### 7. Проброс портов для доступа к веб-интерфейсу
Для доступа к веб-интерфейсу HiveServer2 с локального компьютера, при подключении по SSH к JumpNode/NameNode необходимо добавить флаг `-L` (при условии, что интерфейс работает на порту 10002):
```bash
ssh -L 10002:192.168.10.22:10002 ubuntu@<адрес_entrypoint>
```
После этого веб-интерфейс будет доступен в локальном браузере по адресу `http://localhost:10002`.