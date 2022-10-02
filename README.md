# Дипломный практикум в YandexCloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
      * [Регистрация доменного имени](#регистрация-доменного-имени)
      * [Создание инфраструктуры](#создание-инфраструктуры)
          * [Установка Nginx и LetsEncrypt](#установка-nginx)
          * [Установка кластера MySQL](#установка-mysql)
          * [Установка WordPress](#установка-wordpress)
          * [Установка Gitlab CE, Gitlab Runner и настройка CI/CD](#установка-gitlab)
          * [Установка Prometheus, Alert Manager, Node Exporter и Grafana](#установка-prometheus)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

---
## Цели:

1. Зарегистрировать доменное имя (любое на ваш выбор в любой доменной зоне).
2. Подготовить инфраструктуру с помощью Terraform на базе облачного провайдера YandexCloud.
3. Настроить внешний Reverse Proxy на основе Nginx и LetsEncrypt.
4. Настроить кластер MySQL.
5. Установить WordPress.
6. Развернуть Gitlab CE и Gitlab Runner.
7. Настроить CI/CD для автоматического развёртывания приложения.
8. Настроить мониторинг инфраструктуры с помощью стека: Prometheus, Alert Manager и Grafana.

---
## Этапы выполнения:

### Регистрация доменного имени

Подойдет любое доменное имя на ваш выбор в любой доменной зоне.

ПРИМЕЧАНИЕ: Далее в качестве примера используется домен `you.domain` замените его вашим доменом.

Рекомендуемые регистраторы:
  - [nic.ru](https://nic.ru)
  - [reg.ru](https://reg.ru)

Цель:

1. Получить возможность выписывать [TLS сертификаты](https://letsencrypt.org) для веб-сервера.

Ожидаемые результаты:

1. У вас есть доступ к личному кабинету на сайте регистратора.
2. Вы зарезистрировали домен и можете им управлять (редактировать dns записи в рамках этого домена).

---

Есть зарегистрированное имя `ru-devops.ru` у регистратора `reg.ru`.

![1](./screenshot/01.png)

Делегировал его `DNS` на `ns1.yandexcloud.net` и `ns2.yandexcloud.net`.

```hcl
resource "yandex_dns_zone" "finalwork" {
  name        = "my-finalwork-zone"
  description = "For Netology public zone"

  labels = {
    label1 = "works-public"
  }

  zone    = "ru-devops.ru."
  public  = true

  depends_on = [
    yandex_vpc_subnet.net-101,yandex_vpc_subnet.net-102
  ]
}network
resource "yandex_dns_recordset" "def" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "@.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "gitlab" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "gitlab.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "alertmanager" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "alertmanager.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "grafana" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "grafana.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "prometheus" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "prometheus.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "www" {
  zone_id = yandex_dns_zone.finalwork.id
  name    = "www.ru-devops.ru."
  type    = "A"
  ttl     = 200
  data    = [yandex_vpc_address.addr.external_ipv4_address[0].address]

```
![2](./screenshot/02.png)


Так же буду арендовать статический ip у YC автоматически.

```hcl
resource "yandex_vpc_address" "addr" {
  name = "ip-${terraform.workspace}"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}
```
![3](./screenshot/03.png)


---

### Создание инфраструктуры

Для начала необходимо подготовить инфраструктуру в YC при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
- Следует использовать последнюю стабильную версию [Terraform](https://www.terraform.io/).

Предварительная подготовка:

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя
2. Подготовьте [backend](https://www.terraform.io/docs/language/settings/backends/index.html) для Terraform:
   а. Рекомендуемый вариант: [Terraform Cloud](https://app.terraform.io/)  
   б. Альтернативный вариант: S3 bucket в созданном YC аккаунте.
3. Настройте [workspaces](https://www.terraform.io/docs/language/state/workspaces.html)
   а. Рекомендуемый вариант: создайте два workspace: *stage* и *prod*. В случае выбора этого варианта все последующие шаги должны учитывать факт существования нескольких workspace.  
   б. Альтернативный вариант: используйте один workspace, назвав его *stage*. Пожалуйста, не используйте workspace, создаваемый Terraform-ом по-умолчанию (*default*).
4. Создайте VPC с подсетями в разных зонах доступности.
5. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.
6. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://www.terraform.io/docs/language/settings/backends/index.html) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.

Цель:

1. Повсеместно применять IaaC подход при организации (эксплуатации) инфраструктуры.
2. Иметь возможность быстро создавать (а также удалять) виртуальные машины и сети. С целью экономии денег на вашем аккаунте в YandexCloud.

Ожидаемые результаты:

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий.
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

---

Бэкенд создан в terrafom.cloud, соответственно добавлены файлы настроек backend.tf на локальном диске..
Использую два воркспейса `stage` и `prod`.

![4](./screenshot/04.png)
![5](./screenshot/05.png)


`VPC` в разных зонах доступности, настроена маршрутизация:

```hcl
resource "yandex_vpc_network" "default" {
  name = "net-${terraform.workspace}"
}

resource "yandex_vpc_route_table" "route-table" {
  name                    = "nat-instance-route"
  network_id              = "${yandex_vpc_network.default.id}"
  static_route {
    destination_prefix    = "0.0.0.0/0"
    next_hop_address      = var.lan_proxy_ip
  }
}

resource "yandex_vpc_subnet" "net-101" {
  name = "subnet-${terraform.workspace}-101"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = ["192.168.101.0/24"]
  route_table_id          = yandex_vpc_route_table.route-table.id
}

resource "yandex_vpc_subnet" "net-102" {
  name = "subnet-${terraform.workspace}-102"
  zone           = "ru-central1-b"
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = ["192.168.102.0/24"]
  route_table_id          = yandex_vpc_route_table.route-table.id
}
```
![6](./screenshot/06.png)

Репозиторий с конфигурациями terraform [здесь](./terraform)

Из каталога `stage` запускаем

```bash
export YC_TOKEN=$(yc config get token)
terraform init
terraform plan
terraform apply --auto-approve
```

<details>
<summary>Вывод terraform</summary>

```bash
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ terraform plan
Running plan in the remote backend. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/devopsnetology/stage/runs/run-C2SzdwnnFkfxER7A

Waiting for the plan to start...

Terraform v1.2.9
on linux_amd64
Initializing plugins and modules...
fakewebservices_server.servers[1]: Refreshing state... [id=fakeserver-PbrAaQyNNga721Vk]
fakewebservices_server.servers[0]: Refreshing state... [id=fakeserver-HL9EiboE2uYQKh2k]
fakewebservices_vpc.primary_vpc: Refreshing state... [id=fakevpc-74Q4gJX1PRBshw1y]
fakewebservices_load_balancer.primary_lb: Refreshing state... [id=fakelb-Bge5ZJ5nLwjYFkpq]
fakewebservices_database.prod_db: Refreshing state... [id=fakedb-iVRVVx7yewbT6ZT4]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
  - destroy

Terraform will perform the following actions:

  # fakewebservices_database.prod_db will be destroyed
  # (because fakewebservices_database.prod_db is not in configuration)
  - resource "fakewebservices_database" "prod_db" {
      - id   = "fakedb-iVRVVx7yewbT6ZT4" -> null
      - name = "Production DB" -> null
      - size = 256 -> null
    }

  # fakewebservices_load_balancer.primary_lb will be destroyed
  # (because fakewebservices_load_balancer.primary_lb is not in configuration)
  - resource "fakewebservices_load_balancer" "primary_lb" {
      - id      = "fakelb-Bge5ZJ5nLwjYFkpq" -> null
      - name    = "Primary Load Balancer" -> null
      - servers = [
          - "Server 1",
          - "Server 2",
        ] -> null
    }

  # fakewebservices_server.servers[0] will be destroyed
  # (because fakewebservices_server.servers is not in configuration)
  - resource "fakewebservices_server" "servers" {
      - id   = "fakeserver-HL9EiboE2uYQKh2k" -> null
      - name = "Server 1" -> null
      - type = "t2.micro" -> null
      - vpc  = "Primary VPC" -> null
    }

  # fakewebservices_server.servers[1] will be destroyed
  # (because fakewebservices_server.servers is not in configuration)
  - resource "fakewebservices_server" "servers" {
      - id   = "fakeserver-PbrAaQyNNga721Vk" -> null
      - name = "Server 2" -> null
      - type = "t2.micro" -> null
      - vpc  = "Primary VPC" -> null
    }

  # fakewebservices_vpc.primary_vpc will be destroyed
  # (because fakewebservices_vpc.primary_vpc is not in configuration)
  - resource "fakewebservices_vpc" "primary_vpc" {
      - cidr_block = "0.0.0.0/1" -> null
      - id         = "fakevpc-74Q4gJX1PRBshw1y" -> null
      - name       = "Primary VPC" -> null
    }

  # yandex_dns_recordset.alertmanager will be created
  + resource "yandex_dns_recordset" "alertmanager" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "alertmanager.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.def will be created
  + resource "yandex_dns_recordset" "def" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "@.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.gitlab will be created
  + resource "yandex_dns_recordset" "gitlab" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "gitlab.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.grafana will be created
  + resource "yandex_dns_recordset" "grafana" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "grafana.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.prometheus will be created
  + resource "yandex_dns_recordset" "prometheus" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "prometheus.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.www will be created
  + resource "yandex_dns_recordset" "www" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "www.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_zone.finalwork will be created
  + resource "yandex_dns_zone" "finalwork" {
      + created_at       = (known after apply)
      + description      = "For Netology public zone"
      + folder_id        = (known after apply)
      + id               = (known after apply)
      + labels           = {
          + "label1" = "works-public"
        }
      + name             = "my-finalwork-zone"
      + private_networks = (known after apply)
      + public           = true
      + zone             = "ru-devops.ru."
    }

  # yandex_vpc_address.addr will be created
  + resource "yandex_vpc_address" "addr" {
      + created_at = (known after apply)
      + folder_id  = (known after apply)
      + id         = (known after apply)
      + labels     = (known after apply)
      + name       = "ip-stage"
      + reserved   = (known after apply)
      + used       = (known after apply)

      + external_ipv4_address {
          + address                  = (known after apply)
          + ddos_protection_provider = (known after apply)
          + outgoing_smtp_capability = (known after apply)
          + zone_id                  = "ru-central1-a"
        }
    }

  # yandex_vpc_network.default will be created
  + resource "yandex_vpc_network" "default" {
      + created_at                = (known after apply)
      + default_security_group_id = (known after apply)
      + folder_id                 = (known after apply)
      + id                        = (known after apply)
      + labels                    = (known after apply)
      + name                      = "net-stage"
      + subnet_ids                = (known after apply)
    }

  # yandex_vpc_route_table.route-table will be created
  + resource "yandex_vpc_route_table" "route-table" {
      + created_at = (known after apply)
      + folder_id  = (known after apply)
      + id         = (known after apply)
      + labels     = (known after apply)
      + name       = "nat-instance-route"
      + network_id = (known after apply)

      + static_route {
          + destination_prefix = "0.0.0.0/0"
          + next_hop_address   = "192.168.101.100"
        }
    }

  # yandex_vpc_subnet.net-101 will be created
  + resource "yandex_vpc_subnet" "net-101" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet-stage-101"
      + network_id     = (known after apply)
      + route_table_id = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.101.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-a"
    }

  # yandex_vpc_subnet.net-102 will be created
  + resource "yandex_vpc_subnet" "net-102" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet-stage-102"
      + network_id     = (known after apply)
      + route_table_id = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.102.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-b"
    }

Plan: 12 to add, 0 to change, 5 to destroy.


------------------------------------------------------------------------

Cost estimation:

Resources: 0 of 12 estimated
           $0.0/mo +$0.0


 
 

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ terraform apply --auto-approve
Running apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/devopsnetology/stage/runs/run-TFpm7fscS9csnWpV

Waiting for the plan to start...

Terraform v1.2.9
on linux_amd64
Initializing plugins and modules...

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # yandex_dns_recordset.alertmanager will be created
  + resource "yandex_dns_recordset" "alertmanager" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "alertmanager.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.def will be created
  + resource "yandex_dns_recordset" "def" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "@.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.gitlab will be created
  + resource "yandex_dns_recordset" "gitlab" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "gitlab.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.grafana will be created
  + resource "yandex_dns_recordset" "grafana" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "grafana.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.prometheus will be created
  + resource "yandex_dns_recordset" "prometheus" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "prometheus.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_recordset.www will be created
  + resource "yandex_dns_recordset" "www" {
      + data    = (known after apply)
      + id      = (known after apply)
      + name    = "www.ru-devops.ru."
      + ttl     = 200
      + type    = "A"
      + zone_id = (known after apply)
    }

  # yandex_dns_zone.finalwork will be created
  + resource "yandex_dns_zone" "finalwork" {
      + created_at       = (known after apply)
      + description      = "For Netology public zone"
      + folder_id        = (known after apply)
      + id               = (known after apply)
      + labels           = {
          + "label1" = "works-public"
        }
      + name             = "my-finalwork-zone"
      + private_networks = (known after apply)
      + public           = true
      + zone             = "ru-devops.ru."
    }

  # yandex_vpc_address.addr will be created
  + resource "yandex_vpc_address" "addr" {
      + created_at = (known after apply)
      + folder_id  = (known after apply)
      + id         = (known after apply)
      + labels     = (known after apply)
      + name       = "ip-stage"
      + reserved   = (known after apply)
      + used       = (known after apply)

      + external_ipv4_address {
          + address                  = (known after apply)
          + ddos_protection_provider = (known after apply)
          + outgoing_smtp_capability = (known after apply)
          + zone_id                  = "ru-central1-a"
        }
    }

  # yandex_vpc_network.default will be created
  + resource "yandex_vpc_network" "default" {
      + created_at                = (known after apply)
      + default_security_group_id = (known after apply)
      + folder_id                 = (known after apply)
      + id                        = (known after apply)
      + labels                    = (known after apply)
      + name                      = "net-stage"
      + subnet_ids                = (known after apply)
    }

  # yandex_vpc_route_table.route-table will be created
  + resource "yandex_vpc_route_table" "route-table" {
      + created_at = (known after apply)
      + folder_id  = (known after apply)
      + id         = (known after apply)
      + labels     = (known after apply)
      + name       = "nat-instance-route"
      + network_id = (known after apply)

      + static_route {
          + destination_prefix = "0.0.0.0/0"
          + next_hop_address   = "192.168.101.100"
        }
    }

  # yandex_vpc_subnet.net-101 will be created
  + resource "yandex_vpc_subnet" "net-101" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet-stage-101"
      + network_id     = (known after apply)
      + route_table_id = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.101.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-a"
    }

  # yandex_vpc_subnet.net-102 will be created
  + resource "yandex_vpc_subnet" "net-102" {
      + created_at     = (known after apply)
      + folder_id      = (known after apply)
      + id             = (known after apply)
      + labels         = (known after apply)
      + name           = "subnet-stage-102"
      + network_id     = (known after apply)
      + route_table_id = (known after apply)
      + v4_cidr_blocks = [
          + "192.168.102.0/24",
        ]
      + v6_cidr_blocks = (known after apply)
      + zone           = "ru-central1-b"
    }

Plan: 12 to add, 0 to change, 0 to destroy.


------------------------------------------------------------------------

Cost estimation:

Resources: 0 of 12 estimated
           $0.0/mo +$0.0

------------------------------------------------------------------------

yandex_vpc_address.addr: Creating...
yandex_vpc_address.addr: Creation complete after 4s [id=e9bhqtc1gs3acllspt6g]
yandex_vpc_network.default: Creation complete after 4s [id=enpvdok1djbf74a51m82]
yandex_vpc_route_table.route-table: Creating...
yandex_vpc_route_table.route-table: Creation complete after 1s [id=enpva1gcv9hl90q64mfu]
yandex_vpc_subnet.net-102: Creating...
yandex_vpc_subnet.net-101: Creating...
yandex_vpc_subnet.net-102: Creation complete after 1s [id=e2l51ncp5h54g4juefef]
yandex_vpc_subnet.net-101: Creation complete after 2s [id=e9bqimvlg0mkfd7vquum]
yandex_dns_zone.finalwork: Creating...
yandex_dns_zone.finalwork: Creation complete after 2s [id=dns2ptrh3ekfjdinodgo]
yandex_dns_recordset.grafana: Creating...
yandex_dns_recordset.gitlab: Creating...
yandex_dns_recordset.def: Creating...
yandex_dns_recordset.prometheus: Creating...
yandex_dns_recordset.alertmanager: Creating...
yandex_dns_recordset.www: Creating...
yandex_dns_recordset.grafana: Creation complete after 0s [id=dns2ptrh3ekfjdinodgo/grafana.ru-devops.ru./A]
yandex_dns_recordset.gitlab: Creation complete after 0s [id=dns2ptrh3ekfjdinodgo/gitlab.ru-devops.ru./A]
yandex_dns_recordset.www: Creation complete after 1s [id=dns2ptrh3ekfjdinodgo/www.ru-devops.ru./A]
yandex_dns_recordset.alertmanager: Creation complete after 1s [id=dns2ptrh3ekfjdinodgo/alertmanager.ru-devops.ru./A]
yandex_dns_recordset.prometheus: Creation complete after 1s [id=dns2ptrh3ekfjdinodgo/prometheus.ru-devops.ru./A]
yandex_dns_recordset.def: Creation complete after 1s [id=dns2ptrh3ekfjdinodgo/@.ru-devops.ru./A]

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ 

```

</details>


Далее добавляем файлы .tf с нужными нам характеристиками для создания виртуальных машин 

```bash
terraform init
terraform plan
terraform apply --auto-approve
terraform output -json > output.json
```

<details>
<summary>Вывод terraform</summary>

```
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ terraform apply --auto-approve
Running apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/devopsnetology/stage/runs/run-D2tcywUaSRPv8hmL

Waiting for the plan to start...

Terraform v1.2.9
on linux_amd64
Initializing plugins and modules...
yandex_vpc_network.default: Refreshing state... [id=enpvdok1djbf74a51m82]
yandex_vpc_address.addr: Refreshing state... [id=e9bhqtc1gs3acllspt6g]
yandex_vpc_route_table.route-table: Refreshing state... [id=enpva1gcv9hl90q64mfu]
yandex_vpc_subnet.net-102: Refreshing state... [id=e2l51ncp5h54g4juefef]
yandex_vpc_subnet.net-101: Refreshing state... [id=e9bqimvlg0mkfd7vquum]
yandex_dns_zone.finalwork: Refreshing state... [id=dns2ptrh3ekfjdinodgo]
yandex_dns_recordset.www: Refreshing state... [id=dns2ptrh3ekfjdinodgo/www.ru-devops.ru./A]
yandex_dns_recordset.prometheus: Refreshing state... [id=dns2ptrh3ekfjdinodgo/prometheus.ru-devops.ru./A]
yandex_dns_recordset.def: Refreshing state... [id=dns2ptrh3ekfjdinodgo/@.ru-devops.ru./A]
yandex_dns_recordset.grafana: Refreshing state... [id=dns2ptrh3ekfjdinodgo/grafana.ru-devops.ru./A]
yandex_dns_recordset.gitlab: Refreshing state... [id=dns2ptrh3ekfjdinodgo/gitlab.ru-devops.ru./A]
yandex_dns_recordset.alertmanager: Refreshing state... [id=dns2ptrh3ekfjdinodgo/alertmanager.ru-devops.ru./A]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # yandex_compute_instance.app will be created
  + resource "yandex_compute_instance" "app" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "app.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "app"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8autg36kchufhej85b"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.db01 will be created
  + resource "yandex_compute_instance" "db01" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "db01.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "db01"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8autg36kchufhej85b"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.db02 will be created
  + resource "yandex_compute_instance" "db02" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "db02.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "db02"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8autg36kchufhej85b"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.gitlab will be created
  + resource "yandex_compute_instance" "gitlab" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "gitlab.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "gitlab"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8kdq6d0p8sij7h5qe3"
              + name        = (known after apply)
              + size        = 40
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.monitoring will be created
  + resource "yandex_compute_instance" "monitoring" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "monitoring.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "monitoring"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8autg36kchufhej85b"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.proxy will be created
  + resource "yandex_compute_instance" "proxy" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "proxy"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-a"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8v7ru46kt3s4o5f0uo"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = "192.168.101.100"
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = true
          + nat_ip_address     = "51.250.76.154"
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e9bqimvlg0mkfd7vquum"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 2
          + memory        = 2
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

  # yandex_compute_instance.runner will be created
  + resource "yandex_compute_instance" "runner" {
      + allow_stopping_for_update = true
      + created_at                = (known after apply)
      + folder_id                 = (known after apply)
      + fqdn                      = (known after apply)
      + hostname                  = "runner.ru-devops.ru"
      + id                        = (known after apply)
      + metadata                  = {
          + "ssh-keys" = <<-EOT
                #cloud-config
                users:
                  - name: iurii-devops
                    groups: sudo
                    shell: /bin/bash
                    sudo: ['ALL=(ALL) NOPASSWD:ALL']
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSM9a3wkbMGu6jv1eV3kTe21hlnze4QzIe90Bl+c2uwR+/zh2Io9fbTBFB4JtmC1nTZe6gb1MYZXk2cUwz0vdkMTw8d1zR8iu/sdNLMoAsXlvpIJm9Vs+RNiCDItdgGFehoSrczRJdFYOmYzzMkIUN+ktE28chVAil7dvPqL2BS9Wk+nFH+lQVaSwk8OB6lT59ghDIm+evntea5eXqsrb+jc19wkNBofGEvxAV+FTIhFQKEEBdyQI9Imofw4vW/W7/C9kGyp+d5f8nFxxKI9ilfMgYJtXi/j2Q1xm+bjmJWZYeSl76pdUVq2MTu7/0Jad/9ixmZBrh+yu2VJ2ixb8erDlwa+OfX7SV1TD16TZFQwDY6mw6Y29Wlm4/R9wUVDZZDFjEjzCo8Rat9c2op5af0HZhDlZKC5NH8gV8i6gK+9FFYK60q8/OYTASHLXj+9f5pk0AYxL1wwl1BII7hMn/ZloOgQmP2bsx9XA54zE9oUTQQKTVuUJ2BWsOG0iTfMc= iurii-devops@Host-SPB
                
            EOT
        }
      + name                      = "runner"
      + network_acceleration_type = "standard"
      + platform_id               = "standard-v1"
      + service_account_id        = (known after apply)
      + status                    = (known after apply)
      + zone                      = "ru-central1-b"

      + boot_disk {
          + auto_delete = true
          + device_name = (known after apply)
          + disk_id     = (known after apply)
          + mode        = (known after apply)

          + initialize_params {
              + block_size  = (known after apply)
              + description = (known after apply)
              + image_id    = "fd8autg36kchufhej85b"
              + name        = (known after apply)
              + size        = 10
              + snapshot_id = (known after apply)
              + type        = "network-nvme"
            }
        }

      + network_interface {
          + index              = (known after apply)
          + ip_address         = (known after apply)
          + ipv4               = true
          + ipv6               = (known after apply)
          + ipv6_address       = (known after apply)
          + mac_address        = (known after apply)
          + nat                = false
          + nat_ip_address     = (known after apply)
          + nat_ip_version     = (known after apply)
          + security_group_ids = (known after apply)
          + subnet_id          = "e2l51ncp5h54g4juefef"
        }

      + placement_policy {
          + host_affinity_rules = (known after apply)
          + placement_group_id  = (known after apply)
        }

      + resources {
          + core_fraction = 100
          + cores         = 4
          + memory        = 4
        }

      + scheduling_policy {
          + preemptible = (known after apply)
        }
    }

Plan: 7 to add, 0 to change, 0 to destroy.


------------------------------------------------------------------------

Cost estimation:

Resources: 0 of 19 estimated
           $0.0/mo +$0.0

------------------------------------------------------------------------

yandex_compute_instance.db02: Creating...
yandex_compute_instance.runner: Creating...
yandex_compute_instance.app: Creating...
yandex_compute_instance.db01: Creating...
yandex_compute_instance.gitlab: Creating...
yandex_compute_instance.proxy: Creating...
yandex_compute_instance.db02: Still creating... [10s elapsed]
yandex_compute_instance.monitoring: Still creating... [10s elapsed]
yandex_compute_instance.db01: Still creating... [10s elapsed]
yandex_compute_instance.gitlab: Still creating... [10s elapsed]
yandex_compute_instance.runner: Still creating... [10s elapsed]
yandex_compute_instance.app: Still creating... [10s elapsed]
yandex_compute_instance.proxy: Still creating... [10s elapsed]
yandex_compute_instance.monitoring: Still creating... [20s elapsed]
yandex_compute_instance.db02: Still creating... [20s elapsed]
yandex_compute_instance.db01: Still creating... [20s elapsed]
yandex_compute_instance.runner: Still creating... [20s elapsed]
yandex_compute_instance.gitlab: Still creating... [20s elapsed]
yandex_compute_instance.app: Still creating... [20s elapsed]
yandex_compute_instance.proxy: Still creating... [20s elapsed]
yandex_compute_instance.db01: Creation complete after 26s [id=epdm9kq50tvic189igm3]
yandex_compute_instance.db02: Still creating... [30s elapsed]
yandex_compute_instance.monitoring: Still creating... [30s elapsed]
yandex_compute_instance.app: Still creating... [30s elapsed]
yandex_compute_instance.runner: Still creating... [30s elapsed]
yandex_compute_instance.gitlab: Still creating... [30s elapsed]
yandex_compute_instance.proxy: Still creating... [30s elapsed]
yandex_compute_instance.gitlab: Creation complete after 30s [id=epda7a7dnsbdncn9bvo0]
yandex_compute_instance.app: Creation complete after 30s [id=epdjaoapd5m99fal7p1m]
yandex_compute_instance.db02: Creation complete after 30s [id=epdongnhklmevi1bft3f]
yandex_compute_instance.runner: Creation complete after 31s [id=epdlp32egnfqr8b2k3r7]
yandex_compute_instance.monitoring: Creation complete after 33s [id=epdhdbsibi1g8umt7h62]
yandex_compute_instance.proxy: Still creating... [40s elapsed]
yandex_compute_instance.proxy: Still creating... [50s elapsed]
yandex_compute_instance.proxy: Creation complete after 54s [id=fhmpvc3hv987ubeksbpo]

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ 

```
</details>

![7](./screenshot/07.png)

Cоздаются 7 виртуальных машин.
Создаётся сеть + две подсети + маршруты между ними (`192.168.101.0/24` и `192.168.102.0/24`).
Арендуется IP.

![8](./screenshot/08.png)
![9](./screenshot/09.png)
![10](./screenshot/10.png)
![11](./screenshot/11.png)

В `output.json` выводится информацию о всех выданных `ip` адресах, для дальнейшего использования с `Ansible`.
Содержимое `output.tf` вывожу в `output.json`.

```
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/stage$ terraform output -json > output.json
```

Для начала нам нужно из файла `json` достать нужные данные, используем `jq`.
Для этого запускаем `hosts.sh` следующего содержания:

```bash
# /bin/bash
export internal_ip_address_app_yandex_cloud=$(< output.json jq -r '.internal_ip_address_app_yandex_cloud | .value')
export internal_ip_address_db01_yandex_cloud=$(< output.json jq -r '.internal_ip_address_db01_yandex_cloud | .value')
export internal_ip_address_db02_yandex_cloud=$(< output.json jq -r '.internal_ip_address_db02_yandex_cloud | .value')
export internal_ip_address_gitlab_yandex_cloud=$(< output.json jq -r '.internal_ip_address_gitlab_yandex_cloud | .value')
export internal_ip_address_monitoring_yandex_cloud=$(< output.json jq -r '.internal_ip_address_monitoring_yandex_cloud | .value')
export internal_ip_address_proxy_wan_yandex_cloud=$(< output.json jq -r '.internal_ip_address_proxy_wan_yandex_cloud | .value')
export internal_ip_address_runner_yandex_cloud=$(< output.json jq -r '.internal_ip_address_runner_yandex_cloud | .value')
envsubst < hosts.j2 > ../ansible/hosts
```

Где с помощью `jq` вычленяются нужные данные из файла `output.json` и помещаются в пересенные среды, а затем при помощи `envsubst` заполняется шаблон `hosts.j2` с хостами для `Ansible` и копируется в директорию с `Ansible`. 

Итоговый файл ../ansible/hosts:
```
[proxy]
ru-devops.ru letsencrypt_email=steamdrago777@gmail.com domain_name=ru-devops.ru
[proxy:vars]
ansible_host=178.154.222.77
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[db01]
db01.ru-devops.ru mysql_server_id=1 mysql_replication_role=master
[db01:vars]
ansible_host=192.168.102.7
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'

[db02]
db02.ru-devops.ru mysql_server_id=2 mysql_replication_role=slave
[db02:vars]
ansible_host=192.168.102.28
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'

[app]
app.ru-devops.ru
[app:vars]
ansible_host=192.168.102.20
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'
#ssh 51.250.15.168 -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W app.ovirt:22 -q user@ru-devops.ru -o StrictHostKeyChecking=no "

[gitlab]
gitlab.ru-devops.ru domain_name=ru-devops.ru
[gitlab:vars]
ansible_host=192.168.102.8
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'

[runner]
runner.ru-devops.ru domain_name=ru-devops.ru
[runner:vars]
ansible_host=192.168.102.13
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'

[monitoring]
monitoring.ru-devops.ru domain_name=ru-devops.ru
[monitoring:vars]
ansible_host=192.168.102.9
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q user@ru-devops.ru -o StrictHostKeyChecking=no "'

```
---

---
### Установка Nginx и LetsEncrypt

Необходимо разработать Ansible роль для установки Nginx и LetsEncrypt.

**Для получения LetsEncrypt сертификатов во время тестов своего кода пользуйтесь [тестовыми сертификатами](https://letsencrypt.org/docs/staging-environment/), так как количество запросов к боевым серверам LetsEncrypt [лимитировано](https://letsencrypt.org/docs/rate-limits/).**

Рекомендации:
  - Имя сервера: `you.domain`
  - Характеристики: 2vCPU, 2 RAM, External address (Public) и Internal address.

Цель:

1. Создать reverse proxy с поддержкой TLS для обеспечения безопасного доступа к веб-сервисам по HTTPS.

Ожидаемые результаты:

1. В вашей доменной зоне настроены все A-записи на внешний адрес этого сервера:
    - `https://www.you.domain` (WordPress)
    - `https://gitlab.you.domain` (Gitlab)
    - `https://grafana.you.domain` (Grafana)
    - `https://prometheus.you.domain` (Prometheus)
    - `https://alertmanager.you.domain` (Alert Manager)
2. Настроены все upstream для выше указанных URL, куда они сейчас ведут на этом шаге не важно, позже вы их отредактируете и укажите верные значения.
2. В браузере можно открыть любой из этих URL и увидеть ответ сервера (502 Bad Gateway). На текущем этапе выполнение задания это нормально!

---

Роли взяты из коллекции ansible-galaxy.

Содержимое файла nginxssl.yml:
```yaml
- hosts: proxy
  gather_facts: true
  become:
    true
  become_method:
    sudo
  become_user:
    root
  remote_user:
    user
  roles:
  - nginxssl
```

Содержимое файлов конфигурации роли:
```
upstream app {
    server app.ru-devops.ru:80;
  }
upstream gitlab {
    server gitlab.ru-devops.ru:80;
  }
upstream grafana {
    server monitoring.ru-devops.ru:3000;
  }
upstream prometheus {
    server monitoring.ru-devops.ru:9090;
  }
upstream alertmanager {
    server monitoring.ru-devops.ru:9093;
  }
server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
  listen               443 ssl;
  server_name          {{ domain_name }} www.{{ domain_name }};
  access_log           /var/log/nginx/{{ domain_name }}_access.log;
  error_log            /var/log/nginx/{{ domain_name }}_error.log;

  ssl on;
  ssl_certificate      /etc/letsencrypt/live/{{ domain_name }}/fullchain.pem; 
  ssl_certificate_key  /etc/letsencrypt/live/{{ domain_name }}/privkey.pem;
  proxy_ssl_server_name on;
  proxy_ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  #include              /etc/letsencrypt/options-ssl-nginx.conf;
  location / {
    proxy_pass         http://app;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Frame-Options SAMEORIGIN;
  }
}

server {
  listen          443 ssl;
  server_name     gitlab.{{ domain_name }};
  access_log           /var/log/nginx/gitlab.{{ domain_name }}_access.log;
  error_log            /var/log/nginx/gitlab.{{ domain_name }}_error.log;
  ssl_certificate      /etc/letsencrypt/live/{{ domain_name }}/fullchain.pem;
  ssl_certificate_key  /etc/letsencrypt/live/{{ domain_name }}/privkey.pem;
  include              /etc/letsencrypt/options-ssl-nginx.conf;
  location / {
    proxy_pass         http://gitlab;
    proxy_set_header   Host $http_host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Host $http_host;
    proxy_set_header   X-Forwarded-Proto https;
  }
}

server {
  listen          443 ssl;
  server_name     grafana.{{ domain_name }};
  access_log           /var/log/nginx/grafana.{{ domain_name }}_access.log;
  error_log            /var/log/nginx/grafana.{{ domain_name }}_error.log;
  ssl_certificate      /etc/letsencrypt/live/{{ domain_name }}/fullchain.pem;
  ssl_certificate_key  /etc/letsencrypt/live/{{ domain_name }}/privkey.pem;
  include              /etc/letsencrypt/options-ssl-nginx.conf;
  location / {
    proxy_pass         http://grafana;
    proxy_set_header   Host $http_host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Host $http_host;
    proxy_set_header   X-Forwarded-Proto https;
  }
}

server {
  listen          443 ssl;
  server_name     prometheus.{{ domain_name }};
  access_log           /var/log/nginx/prometheus.{{ domain_name }}_access_log;
  error_log            /var/log/nginx/prometheus.{{ domain_name }}_error_log;
  ssl_certificate      /etc/letsencrypt/live/{{ domain_name }}/fullchain.pem;
  ssl_certificate_key  /etc/letsencrypt/live/{{ domain_name }}/privkey.pem;
  include              /etc/letsencrypt/options-ssl-nginx.conf;
  location / {
    proxy_pass         http://prometheus;
    proxy_set_header   Host $http_host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Host $http_host;
    proxy_set_header   X-Forwarded-Proto https;
  }
}

server {
  listen          443 ssl;
  server_name     alertmanager.{{ domain_name }};
  access_log           /var/log/nginx/alertmanager.{{ domain_name }}_access_log;
  error_log            /var/log/nginx/alertmanager.{{ domain_name }}_error_log;
  ssl_certificate      /etc/letsencrypt/live/{{ domain_name }}/fullchain.pem;
  ssl_certificate_key  /etc/letsencrypt/live/{{ domain_name }}/privkey.pem;
  include              /etc/letsencrypt/options-ssl-nginx.conf;
  location / {
    proxy_pass         http://alertmanager;
    proxy_set_header   Host $http_host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Host $http_host;
    proxy_set_header   X-Forwarded-Proto https;
  }
}

```

Переходим в директорию с `Ansible` и выполняем `ansible-playbook nginx.yml -i hosts`

![12](./screenshot/12.png)

![13](./screenshot/13.png)


<details>
<summary>Вывод Ansible</summary>

```bash
 iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ls
hosts  nginxssl.yml  roles
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-playbook nginxssl.yml -i hosts

PLAY [proxy] **********************************************************************************************************************************************************

TASK [Gathering Facts] ************************************************************************************************************************************************
ok: [ru-devops.ru]

TASK [nginxssl : Install Nginx] ***************************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Set Certbot package name and versions (Ubuntu >= 20.04)] *********************************************************************************************
skipping: [ru-devops.ru]

TASK [nginxssl : Set Certbot package name and versions (Ubuntu < 20.04)] **********************************************************************************************
ok: [ru-devops.ru]

TASK [nginxssl : Add certbot repository] ******************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Install certbot] *************************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Install certbot-nginx plugin] ************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Check if certificate already exists] *****************************************************************************************************************
ok: [ru-devops.ru]

TASK [nginxssl : Force generation of a new certificate] ***************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Add cron job for certbot renewal] ********************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Add nginx.conf] **************************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Add default site] ************************************************************************************************************************************
changed: [ru-devops.ru]

TASK [nginxssl : Add site conf] ***************************************************************************************************************************************
changed: [ru-devops.ru]

RUNNING HANDLER [nginxssl : nginx systemd] ****************************************************************************************************************************
ok: [ru-devops.ru]

RUNNING HANDLER [nginxssl : nginx restart] ****************************************************************************************************************************
changed: [ru-devops.ru]

PLAY RECAP ************************************************************************************************************************************************************
ru-devops.ru               : ok=14   changed=10   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$  

```

</details>

---

___
### Установка кластера MySQL

Необходимо разработать Ansible роль для установки кластера MySQL.

Рекомендации:
  - Имена серверов: `db01.you.domain` и `db02.you.domain`
  - Характеристики: 4vCPU, 4 RAM, Internal address.

Цель:

1. Получить отказоустойчивый кластер баз данных MySQL.

Ожидаемые результаты:

1. MySQL работает в режиме репликации Master/Slave.
2. В кластере автоматически создаётся база данных c именем `wordpress`.
3. В кластере автоматически создаётся пользователь `wordpress` с полными правами на базу `wordpress` и паролем `wordpress`.

**Вы должны понимать, что в рамках обучения это допустимые значения, но в боевой среде использование подобных значений не приемлимо! Считается хорошей практикой использовать логины и пароли повышенного уровня сложности. В которых будут содержаться буквы верхнего и нижнего регистров, цифры, а также специальные символы!**

---

Конфигурация `master.cnf.j2`:

```bash
[mysqld]
# Replication
server-id = 1
log-bin = mysql-bin
log-bin-index = mysql-bin.index
log-error = mysql-bin.err
relay-log = relay-bin
relay-log-info-file = relay-bin.info
relay-log-index = relay-bin.index
expire_logs_days=7
binlog-do-db = {{ db_name }}
```

Конфигурация `slave.cnf.j2`:

```bash
[mysqld]
# Replication
server-id = 2
relay-log = relay-bin
relay-log-info-file = relay-log.info
relay-log-index = relay-log.index
replicate-do-db = {{ db_name }}
```
Выполняем установку модуля mysql:
```
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-galaxy collection install community.mysql
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Downloading https://galaxy.ansible.com/download/community-mysql-3.5.1.tar.gz to /home/iurii-devops/.ansible/tmp/ansible-local-39610bvynsu7r/tmpfjgqutkb/community-mysql-3.5.1-xz90scjl
Installing 'community.mysql:3.5.1' to '/home/iurii-devops/.ansible/collections/ansible_collections/community/mysql'
community.mysql:3.5.1 was installed successfully

```
Для создания кластера выполняем `ansible-playbook mysql.yml -i hosts`

<details>
<summary>Вывод Ansible</summary>

```bash

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-playbook mysql.yml -i hosts

PLAY [db01 db02] ******************************************************************************************************************************************************

TASK [Gathering Facts] ************************************************************************************************************************************************
ok: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Installing Mysql and dependencies] **********************************************************************************************************************
ok: [db01.ru-devops.ru] => (item=mysql-server)
ok: [db02.ru-devops.ru] => (item=mysql-server)
ok: [db01.ru-devops.ru] => (item=mysql-client)
ok: [db02.ru-devops.ru] => (item=mysql-client)
ok: [db01.ru-devops.ru] => (item=python3-mysqldb)
ok: [db02.ru-devops.ru] => (item=python3-mysqldb)
ok: [db01.ru-devops.ru] => (item=libmysqlclient-dev)
ok: [db02.ru-devops.ru] => (item=libmysqlclient-dev)

TASK [mysql : start and enable mysql service] *************************************************************************************************************************
ok: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Creating database wordpress] ****************************************************************************************************************************
ok: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Creating mysql user wordpress] **************************************************************************************************************************
ok: [db02.ru-devops.ru]
ok: [db01.ru-devops.ru]

TASK [mysql : Enable remote login to mysql] ***************************************************************************************************************************
ok: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Remove anonymous MySQL users.] **************************************************************************************************************************
ok: [db02.ru-devops.ru]
ok: [db01.ru-devops.ru]

TASK [mysql : Remove MySQL test database.] ****************************************************************************************************************************
ok: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Copy master.cnf] ****************************************************************************************************************************************
skipping: [db02.ru-devops.ru]
ok: [db01.ru-devops.ru]

TASK [mysql : Copy slave.cnf] *****************************************************************************************************************************************
skipping: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Ensure replication user exists on master.] **************************************************************************************************************
skipping: [db02.ru-devops.ru]
ok: [db01.ru-devops.ru]

TASK [mysql : check slave replication status] *************************************************************************************************************************
skipping: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru]

TASK [mysql : Check master replication status] ************************************************************************************************************************
skipping: [db01.ru-devops.ru]
ok: [db02.ru-devops.ru -> db01.ru-devops.ru(192.168.102.23)]

TASK [mysql : configure replication on the slave] *********************************************************************************************************************
skipping: [db01.ru-devops.ru]
changed: [db02.ru-devops.ru]

TASK [mysql : start replication] **************************************************************************************************************************************
skipping: [db01.ru-devops.ru]
changed: [db02.ru-devops.ru]

PLAY RECAP ************************************************************************************************************************************************************
db01.ru-devops.ru          : ok=10   changed=0    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0   
db02.ru-devops.ru          : ok=13   changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   

```

</details>

---

![14](./screenshot/14.png)

___
### Установка WordPress

Необходимо разработать Ansible роль для установки WordPress.

Рекомендации:
  - Имя сервера: `app.you.domain`
  - Характеристики: 4vCPU, 4 RAM, Internal address.

Цель:

1. Установить [WordPress](https://wordpress.org/download/). Это система управления содержимым сайта ([CMS](https://ru.wikipedia.org/wiki/Система_управления_содержимым)) с открытым исходным кодом.


По данным W3techs, WordPress используют 64,7% всех веб-сайтов, которые сделаны на CMS. Это 41,1% всех существующих в мире сайтов. Эту платформу для своих блогов используют The New York Times и Forbes. Такую популярность WordPress получил за удобство интерфейса и большие возможности.

Ожидаемые результаты:

1. Виртуальная машина на которой установлен WordPress и Nginx/Apache (на ваше усмотрение).
2. В вашей доменной зоне настроена A-запись на внешний адрес reverse proxy:
    - `https://www.you.domain` (WordPress)
3. На сервере `you.domain` отредактирован upstream для выше указанного URL и он смотрит на виртуальную машину на которой установлен WordPress.
4. В браузере можно открыть URL `https://www.you.domain` и увидеть главную страницу WordPress.

---

Далее ставим `Wordpress`. Воспользуемся ролью из ansible-galaxy.
Так же выполним предварительные настройки `Wordpress`, шаблонизировав `wp-config.php.j2`.
А именно внесем туда:

```bash
define( 'DB_NAME', '{{ db_name }}' );
define( 'DB_USER', '{{ db_user }}' );
define( 'DB_PASSWORD', '{{ db_password }}' );
define( 'DB_HOST', '{{ db_host }}' );
```
Выполняем `ansible-playbook app.yml -i hosts`

<details>
<summary>Вывод Ansible</summary>

```bash

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-playbook app.yml -i hosts

PLAY [app] ********************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************************************************************************************
ok: [app.ru-devops.ru]

TASK [app : Install Nginx] ****************************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : Disable default site] *********************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : Remove default site] **********************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : install php] ******************************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru] => (item=php8.1)
changed: [app.ru-devops.ru] => (item=php8.1-cgi)
changed: [app.ru-devops.ru] => (item=php8.1-fpm)
changed: [app.ru-devops.ru] => (item=php8.1-memcache)
changed: [app.ru-devops.ru] => (item=php8.1-memcached)
changed: [app.ru-devops.ru] => (item=php8.1-mysql)
changed: [app.ru-devops.ru] => (item=php8.1-gd)
changed: [app.ru-devops.ru] => (item=php8.1-curl)
changed: [app.ru-devops.ru] => (item=php8.1-xmlrpc)

TASK [app : Uninstall Apache2] ************************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : change listen socket] *********************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : install nginx configuration] **************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : activate site configuration] **************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : download WordPress] ***********************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : creating directory for WordPress] *********************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : unpack WordPress installation] ************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

TASK [app : Set up wp-config] *************************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

RUNNING HANDLER [app : nginx systemd] *****************************************************************************************************************************************************************************************
ok: [app.ru-devops.ru]

RUNNING HANDLER [app : nginx restart] *****************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

RUNNING HANDLER [app : restart php-fpm] ***************************************************************************************************************************************************************************************
changed: [app.ru-devops.ru]

PLAY RECAP ********************************************************************************************************************************************************************************************************************
app.ru-devops.ru           : ok=16   changed=14   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ 

```

</details>

Теперь внесём данные на сайте ru-devops.ru.

И после выполним проверку изменений перейдя на сайт www.ru-devops.ru:

![15](./screenshot/15.png)

![16](./screenshot/16.png)

![17](./screenshot/17.png)

![18](./screenshot/18.png)

![19](./screenshot/19.png)

![20](./screenshot/20.png)
---

---
### Установка Gitlab CE и Gitlab Runner

Необходимо настроить CI/CD систему для автоматического развертывания приложения при изменении кода.

Рекомендации:
  - Имена серверов: `gitlab.you.domain` и `runner.you.domain`
  - Характеристики: 4vCPU, 4 RAM, Internal address.

Цель:
1. Построить pipeline доставки кода в среду эксплуатации, то есть настроить автоматический деплой на сервер `app.you.domain` при коммите в репозиторий с WordPress.

Подробнее об [Gitlab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/)

Ожидаемый результат:

1. Интерфейс Gitlab доступен по https.
2. В вашей доменной зоне настроена A-запись на внешний адрес reverse proxy:
    - `https://gitlab.you.domain` (Gitlab)
3. На сервере `you.domain` отредактирован upstream для выше указанного URL и он смотрит на виртуальную машину на которой установлен Gitlab.
3. При любом коммите в репозиторий с WordPress и создании тега (например, v1.0.0) происходит деплой на виртуальную машину.

---

По советам коллег использовал ubuntu 20.04, т.к. в более поздних версиях ОС появляются ошибки в ansible-playbook.

Изменяем конфигурацию gitlab для prometheus:

```bash
prometheus['enable'] = false

node_exporter['listen_address'] = '0.0.0.0:9100'

```

Для автаматизации добавляем значение переменной окружения `GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN`:

```bash
  environment:
    GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN: "{{ gitlab_runners_registration_token }}"
```

Также после обсуждения в группе, было решено принудительно устанавливать пароль root в `Task`, для избежания дополнительных ошибок:

```yaml
- name: use the rails console to change the password
# {{':'}} is to escape the colon
  shell: sudo gitlab-rails runner "user = User.where(id{{':'}} 1).first; user.password = '{{gitlab_initial_root_password}}'; user.password_confirmation = '{{gitlab_initial_root_password}}'; user.save!"
  notify: restart gitlab
```

Выполняем `ansible-playbook gitlab.yml -i hosts`:

<details>
<summary>Вывод Ansible</summary>

```bash

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-playbook gitlab.yml -i hosts

PLAY [gitlab] *****************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************************************************************************************
ok: [gitlab.ru-devops.ru]

TASK [gitlab : Check if GitLab configuration file already exists.] ************************************************************************************************************************************************************
ok: [gitlab.ru-devops.ru]

TASK [gitlab : Check if GitLab is already installed.] *************************************************************************************************************************************************************************
ok: [gitlab.ru-devops.ru]

TASK [gitlab : Install GitLab dependencies (Debian).] *************************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

TASK [gitlab : Install GitLab dependencies.] **********************************************************************************************************************************************************************************
ok: [gitlab.ru-devops.ru] => (item=curl)
ok: [gitlab.ru-devops.ru] => (item=tzdata)
changed: [gitlab.ru-devops.ru] => (item=perl)
ok: [gitlab.ru-devops.ru] => (item=openssl)
changed: [gitlab.ru-devops.ru] => (item=postfix)
ok: [gitlab.ru-devops.ru] => (item=openssh-server)

TASK [gitlab : Download GitLab repository installation script.] ***************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

TASK [gitlab : Install GitLab repository.] ************************************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

TASK [gitlab : Define the Gitlab package name.] *******************************************************************************************************************************************************************************
skipping: [gitlab.ru-devops.ru]

TASK [gitlab : Install GitLab] ************************************************************************************************************************************************************************************************
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC POLL on gitlab.ru-devops.ru: jid=174065687158.5154 started=1 finished=0
ASYNC OK on gitlab.ru-devops.ru: jid=174065687158.5154
changed: [gitlab.ru-devops.ru]

TASK [gitlab : Reconfigure GitLab (first run).] *******************************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

TASK [gitlab : Create GitLab SSL configuration folder.] ***********************************************************************************************************************************************************************
skipping: [gitlab.ru-devops.ru]

TASK [gitlab : Create self-signed certificate.] *******************************************************************************************************************************************************************************
skipping: [gitlab.ru-devops.ru]

TASK [gitlab : Fail when Password is shorter than 8 chars] ********************************************************************************************************************************************************************
skipping: [gitlab.ru-devops.ru]

TASK [gitlab : Copy GitLab configuration file.] *******************************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

TASK [gitlab : use the rails console to change the password] ******************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

RUNNING HANDLER [gitlab : restart gitlab] *************************************************************************************************************************************************************************************
changed: [gitlab.ru-devops.ru]

PLAY RECAP ********************************************************************************************************************************************************************************************************************
gitlab.ru-devops.ru        : ok=12   changed=9    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ 


```

</details>

![21](./screenshot/21.png)

Далее создадим проект `wordpress`.

![22](./screenshot/22.png)

Теперь нужно зайти по `ssh` на хост `app` с `wordpress` и запушить его в репозиторий.

План действий:

```bash
1. Зайти по ssh на app.ru-devops.ru
2. Добавить в репозиторий gitlab.ru-devops.ru файлы из папки wordpress (на app.ru-devops.ru)
3. Сделать Push 
```

Что получилось:
```
Необходимо создать файл с дейсвующим id_rsa/id_rsa.pub на сервере app.ru-devops.ru, чтобы можно было выполнить подключение с сервера ru-devops.ru   
```
Для просторты настройки, репозиторий добавлен с помощью git clone. Теперь можно выполнить push.
 
```bash
user@app:/var/www/wordpress$ sudo git push
Username for 'http://gitlab.ru-devops.ru': root
Password for 'http://root@gitlab.ru-devops.ru': 
Enumerating objects: 3109, done.
Counting objects: 100% (3109/3109), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3039/3039), done.
Writing objects: 100% (3108/3108), 19.26 MiB | 6.47 MiB/s, done.
Total 3108 (delta 512), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (512/512), done.
To http://gitlab.ru-devops.ru/root/wordpress.git
   724335a..d01287a  main -> main
```

![23](./screenshot/23.png)

Теперь подготовим `pipeline` и запустим `runner`. 

Первое, в нашем проекте, заходим в `Settings` -> `CI/CD` -> `Variables` и добавляем переменную `ssh_key`, содержащую закрытую часть ключа, для авторизации на сервере `app` с нашего `runner`а.

![24](./screenshot/24.png)

Так же в `Settings` -> `CI/CD` -> `Runners` убедимся, что сейчас `runner`ов нет.

![25](./screenshot/25.png)

Настраиваем `pipeline`, заходим в `CI/CD` -> `Pipelines` -> `Editor`.

Жмем `Configure pipeline` и заменяем всё следующим кодом:

```yaml
---
before_script:
  - 'which ssh-agent || ( apt-get update -y && apt-get install openssh-client -y )'
  - eval $(ssh-agent -s)
  - echo "$ssh_key" | tr -d '\r' | ssh-add -
  - mkdir -p ~/.ssh
  - chmod 700 ~/.ssh

stages:
  - deploy

deploy-job:
  stage: deploy
  script:
    - echo "Deploying files..."
    - ssh -o StrictHostKeyChecking=no user@app.ru-devops.ru sudo chown user /var/www/wordpress/ -R
    - rsync -arvzc -e "ssh -o StrictHostKeyChecking=no" ./* user@app.ru-devops.ru:/var/www/wordpress/
    - ssh -o StrictHostKeyChecking=no user@app.ru-devops.ru sudo chown www-data /var/www/wordpress/ -R 
```

![26](./screenshot/26.png)

![27](./screenshot/27.png)

Вышеуказанный код выполняет следущее:
- добавляет закрытый ключ `ssh` из переменной `ssh_key` на `runner`а
- Подключается по ssh к серверу с `wordpress`, меняет владельца всего содержимого каталога `/var/www/wordpress/` на `user`
- Утилитой `rsync` синхронизирует файлы и папки.
- Меняет владельца всего содержимого каталога `/var/www/wordpress/` на `www-data`

Теперь разворачиваем `runner`.

В `defaults` -> `main.yml` указываем следующее, чтобы `runner` нашел `gitlab` и подключился к нему:

```yaml
# GitLab coordinator URL
gitlab_runner_coordinator_url: 'http://gitlab.{{ domain_name }}'
# GitLab registration token
gitlab_runner_registration_token: 'GR13489419xaozkLzQNuDyN22cnkv'
```
Устанавливаем дополнительные модули для запуска роли:
```
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-galaxy collection install community.windows
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Downloading https://galaxy.ansible.com/download/community-windows-1.11.0.tar.gz to /home/iurii-devops/.ansible/tmp/ansible-local-1475762yhvz87r/tmp7ji0y242/community-windows-1.11.0-4z65cyv6
Installing 'community.windows:1.11.0' to '/home/iurii-devops/.ansible/collections/ansible_collections/community/windows'
community.windows:1.11.0 was installed successfully
'ansible.windows:1.11.1' is already installed, skipping.

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-galaxy collection install ansible.windows
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Downloading https://galaxy.ansible.com/download/ansible-windows-1.11.1.tar.gz to /home/iurii-devops/.ansible/tmp/ansible-local-147539pva6569_/tmpakdkzkgw/ansible-windows-1.11.1-icjmi7v1
Installing 'ansible.windows:1.11.1' to '/home/iurii-devops/.ansible/collections/ansible_collections/ansible/windows'
ansible.windows:1.11.1 was installed successfully
```
 
Выполняем `ansible-playbook runner.yml -i hosts`. Использована готовая роль с ansible-galaxy, внесены необходимые доработки.

<details>
<summary>Вывод Ansible</summary>

```bash
iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ ansible-playbook runner.yml -i hosts

PLAY [runner] *********************************************************************************************************************************************************

TASK [Gathering Facts] ************************************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Load platform-specific variables] **********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : (Container) Pull Image from Registry] ******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Container) Define Container volume Path] **************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Container) List configured runners] *******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Container) Check runner is registered] ****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : configured_runners?] ***********************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : verified_runners?] *************************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Container) Register GitLab Runner] ********************************************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 

TASK [runner : Create .gitlab-runner dir] *****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Ensure config.toml exists] *****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Set concurrent option] *********************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add listen_address to config] **************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add log_format to config] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add sentry dsn to config] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add session server listen_address to config] ***********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add session server advertise_address to config] ********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add session server session_timeout to config] **********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Get existing config.toml] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Get pre-existing runner configs] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Create temporary directory] ****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Write config section for each runner] ******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Assemble new config.toml] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Container) Start the container] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Debian) Get Gitlab repository installation script] ****************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : (Debian) Install Gitlab repository] ********************************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : (Debian) Update gitlab_runner_package_name] ************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Debian) Set gitlab_runner_package_name] ***************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : (Debian) Install GitLab Runner] ************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Debian) Install GitLab Runner] ************************************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : (Debian) Remove ~/gitlab-runner/.bash_logout on debian buster and ubuntu focal] ************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ********************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : Add reload command to GitLab Runner system service] ****************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : Configure graceful stop for GitLab Runner system service] **********************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : Force systemd to reread configs] ***********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : (RedHat) Get Gitlab repository installation script] ****************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (RedHat) Install Gitlab repository] ********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (RedHat) Update gitlab_runner_package_name] ************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (RedHat) Set gitlab_runner_package_name] ***************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (RedHat) Install GitLab Runner] ************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add reload command to GitLab Runner system service] ****************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Configure graceful stop for GitLab Runner system service] **********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Force systemd to reread configs] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Check gitlab-runner executable exists] *********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Set fact -> gitlab_runner_exists] **************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Get existing version] **************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Set fact -> gitlab_runner_existing_version] ****************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Precreate gitlab-runner log directory] *********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Download GitLab Runner] ************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Setting Permissions for gitlab-runner executable] **********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Install GitLab Runner] *************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Start GitLab Runner] ***************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Stop GitLab Runner] ****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Download GitLab Runner] ************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Setting Permissions for gitlab-runner executable] **********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (MacOS) Start GitLab Runner] ***************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Arch) Set gitlab_runner_package_name] *****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Arch) Install GitLab Runner] **************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add reload command to GitLab Runner system service] ****************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Configure graceful stop for GitLab Runner system service] **********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Force systemd to reread configs] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Unix) List configured runners] ************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : (Unix) Check runner is registered] *********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : (Unix) Register GitLab Runner] *************************************************************************************************************************
included: /home/iurii-devops/PycharmProjects/diplom/terraform.tfstate.d/ansible/roles/runner/tasks/register-runner.yml for runner.ru-devops.ru => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []})

TASK [runner : remove config.toml file] *******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Create .gitlab-runner dir] *****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Ensure config.toml exists] *****************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Construct the runner command without secrets] **********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Register runner to GitLab] *****************************************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : Create .gitlab-runner dir] *****************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Ensure config.toml exists] *****************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Set concurrent option] *********************************************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : Add listen_address to config] **************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add log_format to config] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add sentry dsn to config] ******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : Add session server listen_address to config] ***********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Add session server advertise_address to config] ********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Add session server session_timeout to config] **********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Get existing config.toml] ******************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Get pre-existing runner configs] ***********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Create temporary directory] ****************************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : Write config section for each runner] ******************************************************************************************************************
included: /home/iurii-devops/PycharmProjects/diplom/terraform.tfstate.d/ansible/roles/runner/tasks/config-runner.yml for runner.ru-devops.ru => (item=concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

)
included: /home/iurii-devops/PycharmProjects/diplom/terraform.tfstate.d/ansible/roles/runner/tasks/config-runner.yml for runner.ru-devops.ru => (item=  name = "runner"
  output_limit = 4096
  url = "http://gitlab.ru-devops.ru"
  id = 1
  token = "Nncxs2ofjxn7UBan71se"
  token_obtained_at = 2022-10-02T08:51:34Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
)

TASK [runner : conf[1/2]: Create temporary file] **********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[1/2]: Isolate runner configuration] ***************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : include_tasks] *****************************************************************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 

TASK [runner : conf[1/2]: Remove runner config] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 

TASK [runner : conf[2/2]: Create temporary file] **********************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: Isolate runner configuration] ***************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : include_tasks] *****************************************************************************************************************************************
included: /home/iurii-devops/PycharmProjects/diplom/terraform.tfstate.d/ansible/roles/runner/tasks/update-config-runner.yml for runner.ru-devops.ru => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []})

TASK [runner : conf[2/2]: runner[1/1]: Set concurrent limit option] ***************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set coordinator URL] ***********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set clone URL] *****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set environment option] ********************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set pre_clone_script] **********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set pre_build_script] **********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set tls_ca_file] ***************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set post_build_script] *********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set runner executor option] ****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set runner shell option] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set runner executor section] ***************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set output_limit option] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set runner docker image option] ************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker helper image option] ************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker privileged option] **************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker wait_for_services_timeout option] ***********************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker tlsverify option] ***************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker shm_size option] ****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker disable_cache option] ***********************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker DNS option] *********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker DNS search option] **************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker pull_policy option] *************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker volumes option] *****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker devices option] *****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set runner docker network option] **********************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set custom_build_dir section] **************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set docker custom_build_dir-enabled option] ************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache section] *************************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 section] **********************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache gcs section] *********************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache azure section] *******************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache type option] *********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache path option] *********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache shared option] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 server addresss] **************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 access key] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 secret key] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 bucket name option] ***********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 bucket location option] *******************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache s3 insecure option] **************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache gcs bucket name] *****************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache gcs credentials file] ************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache gcs access id] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache gcs private key] *****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache azure account name] **************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache azure account key] ***************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache azure container name] ************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache azure storage domain] ************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set ssh user option] ***********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set ssh host option] ***********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set ssh port option] ***********************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set ssh password option] *******************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set ssh identity file option] **************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set virtualbox base name option] ***********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set virtualbox base snapshot option] *******************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set virtualbox base folder option] *********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set virtualbox disable snapshots option] ***************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set builds dir file option] ****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Set cache dir file option] *****************************************************************************************************
ok: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: runner[1/1]: Ensure directory permissions] **************************************************************************************************
skipping: [runner.ru-devops.ru] => (item=) 
skipping: [runner.ru-devops.ru] => (item=) 

TASK [runner : conf[2/2]: runner[1/1]: Ensure directory access test] **************************************************************************************************
skipping: [runner.ru-devops.ru] => (item=) 
skipping: [runner.ru-devops.ru] => (item=) 

TASK [runner : conf[2/2]: runner[1/1]: Ensure directory access fail on error] *****************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'changed': False, 'skipped': True, 'skip_reason': 'Conditional result was False', 'item': '', 'ansible_loop_var': 'item'}) 
skipping: [runner.ru-devops.ru] => (item={'changed': False, 'skipped': True, 'skip_reason': 'Conditional result was False', 'item': '', 'ansible_loop_var': 'item'}) 

TASK [runner : include_tasks] *****************************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : conf[2/2]: Remove runner config] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 

TASK [runner : Assemble new config.toml] ******************************************************************************************************************************
changed: [runner.ru-devops.ru]

TASK [runner : (Windows) Check gitlab-runner executable exists] *******************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Set fact -> gitlab_runner_exists] ************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Get existing version] ************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Set fact -> gitlab_runner_existing_version] **************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Ensure install directory exists] *************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Download GitLab Runner] **********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Install GitLab Runner] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Install GitLab Runner] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Make sure runner is stopped] *****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Download GitLab Runner] **********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) List configured runners] *********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Check runner is registered] ******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Register GitLab Runner] **********************************************************************************************************************
skipping: [runner.ru-devops.ru] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 

TASK [runner : (Windows) Create .gitlab-runner dir] *******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Ensure config.toml exists] *******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Set concurrent option] ***********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Add listen_address to config] ****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Add sentry dsn to config] ********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Add session server listen_address to config] *************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Add session server advertise_address to config] **********************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Add session server session_timeout to config] ************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Get existing config.toml] ********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Get pre-existing global config] **************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Get pre-existing runner configs] *************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Create temporary directory] ******************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Write config section for each runner] ********************************************************************************************************
skipping: [runner.ru-devops.ru] => (item=concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

) 
skipping: [runner.ru-devops.ru] => (item=  name = "runner"
  output_limit = 4096
  url = "http://gitlab.ru-devops.ru"
  id = 1
  token = "Nncxs2ofjxn7UBan71se"
  token_obtained_at = 2022-10-02T08:51:34Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
) 

TASK [runner : (Windows) Create temporary file config.toml] ***********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Write global config to file] *****************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Create temporary file runners-config.toml] ***************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Assemble runners files in config dir] ********************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Assemble new config.toml] ********************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Verify config] *******************************************************************************************************************************
skipping: [runner.ru-devops.ru]

TASK [runner : (Windows) Start GitLab Runner] *************************************************************************************************************************
skipping: [runner.ru-devops.ru]

RUNNING HANDLER [runner : restart_gitlab_runner] **********************************************************************************************************************
changed: [runner.ru-devops.ru]

RUNNING HANDLER [runner : restart_gitlab_runner_macos] ****************************************************************************************************************
skipping: [runner.ru-devops.ru]

PLAY RECAP ************************************************************************************************************************************************************
runner.ru-devops.ru        : ok=81   changed=19   unreachable=0    failed=0    skipped=111  rescued=0    ignored=0   

iurii-devops@Host-SPB:~/PycharmProjects/diplom/terraform.tfstate.d/ansible$ 
```

</details>

Проверяем что `runner` подключился к `gitlab`, смотрим `Settings` -> `CI/CD` -> `Runners`

![28](./screenshot/28.png)

В `CI/CD` -> `Pipelines` видим что `pipeline` выполнился.

![29](./screenshot/29.png)

![30](./screenshot/30.png)
 
Теперь сделаем коммит в репозиторий и еще раз глянем на `Pipelines`

![31](./screenshot/31.png)

![32](./screenshot/32.png)

Проверим `Pipelines`, видим что он выполнился

![33](./screenshot/33.png)

![34](./screenshot/34.png)

И сам файл на мервере `wordpress`

![35](./screenshot/35.png)
---

___
### Установка Prometheus, Alert Manager, Node Exporter и Grafana

Необходимо разработать Ansible роль для установки Prometheus, Alert Manager и Grafana.

Рекомендации:
  - Имя сервера: `monitoring.you.domain`
  - Характеристики: 4vCPU, 4 RAM, Internal address.

Цель:

1. Получение метрик со всей инфраструктуры.

Ожидаемые результаты:

1. Интерфейсы Prometheus, Alert Manager и Grafana доступены по https.
2. В вашей доменной зоне настроены A-записи на внешний адрес reverse proxy:
  - `https://grafana.you.domain` (Grafana)
  - `https://prometheus.you.domain` (Prometheus)
  - `https://alertmanager.you.domain` (Alert Manager)
3. На сервере `you.domain` отредактированы upstreams для выше указанных URL и они смотрят на виртуальную машину на которой установлены Prometheus, Alert Manager и Grafana.
4. На всех серверах установлен Node Exporter и его метрики доступны Prometheus.
5. У Alert Manager есть необходимый [набор правил](https://awesome-prometheus-alerts.grep.to/rules.html) для создания алертов.
2. В Grafana есть дашборд отображающий метрики из Node Exporter по всем серверам.
3. В Grafana есть дашборд отображающий метрики из MySQL (*).
4. В Grafana есть дашборд отображающий метрики из WordPress (*).

*Примечание: дашборды со звёздочкой являются опциональными заданиями повышенной сложности их выполнение желательно, но не обязательно.*

---

Литература:

[https://medium.com/devops4me/install-grafana-prometheus-node-exporter-using-ansible-1771e649a4b3](https://medium.com/devops4me/install-grafana-prometheus-node-exporter-using-ansible-1771e649a4b3)

[https://github.com/cloudalchemy/ansible-node-exporter](https://github.com/cloudalchemy/ansible-node-exporter)

Для разворачивания `Node Exporter` выполняем `ansible-playbook node_exporter.yml -i hosts`

Разворачиваем везде, кроме сервера `gitlab`, т.к. там уже есть, он ставится вместе с `gitlab`ом.

<details>
<summary>Вывод Ansible</summary>

```bash

user@user-ubuntu:~/devops/diplom/ansible$ ansible-playbook node_exporter.yml -i hosts

PLAY [app db01 db02 monitoring runner proxy] ************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************
ok: [db02.ovirt.ru]
ok: [db01.ovirt.ru]
ok: [app.ovirt.ru]
ok: [runner.ovirt.ru]
ok: [monitoring.ovirt.ru]
ok: [ovirt.ru]

TASK [node_exporter : check if node exporter exist] *****************************************************************************************************************************
ok: [db02.ovirt.ru]
ok: [monitoring.ovirt.ru]
ok: [runner.ovirt.ru]
ok: [app.ovirt.ru]
ok: [db01.ovirt.ru]
ok: [ovirt.ru]

TASK [node_exporter : Create the node_exporter group] ***************************************************************************************************************************
changed: [db02.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [app.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : Create the node_exporter user] ****************************************************************************************************************************
changed: [monitoring.ovirt.ru]
changed: [db02.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [app.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : Create node exporter config dir] **************************************************************************************************************************
changed: [db02.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [app.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : if node exporter exist get version] ***********************************************************************************************************************
skipping: [app.ovirt.ru]
skipping: [db01.ovirt.ru]
skipping: [db02.ovirt.ru]
skipping: [monitoring.ovirt.ru]
skipping: [runner.ovirt.ru]
skipping: [ovirt.ru]

TASK [node_exporter : download and unzip node exporter if not exist] ************************************************************************************************************
changed: [runner.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [app.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [db02.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : move the binary to the final destination] *****************************************************************************************************************
changed: [monitoring.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [db02.ovirt.ru]
changed: [app.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : clean] ****************************************************************************************************************************************************
changed: [db02.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [app.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : install service] ******************************************************************************************************************************************
changed: [db02.ovirt.ru]
changed: [app.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : meta] *****************************************************************************************************************************************************

RUNNING HANDLER [node_exporter : reload_daemon_and_restart_node_exporter] *******************************************************************************************************
changed: [db02.ovirt.ru]
changed: [monitoring.ovirt.ru]
changed: [db01.ovirt.ru]
changed: [runner.ovirt.ru]
changed: [app.ovirt.ru]
changed: [ovirt.ru]

TASK [node_exporter : service always started] ***********************************************************************************************************************************
ok: [db02.ovirt.ru]
ok: [app.ovirt.ru]
ok: [db01.ovirt.ru]
ok: [monitoring.ovirt.ru]
ok: [runner.ovirt.ru]
ok: [ovirt.ru]

PLAY RECAP **********************************************************************************************************************************************************************
app.ovirt.ru               : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
db01.ovirt.ru              : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
db02.ovirt.ru              : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
monitoring.ovirt.ru        : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
ovirt.ru                   : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
runner.ovirt.ru            : ok=11   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0 
```

</details>

Для разворачивания `Alertmanager`, `Prometheus` и `Grafana` выполняем `ansible-playbook monitoring.yml -i hosts`

Ставится `Prometheus` и подключаются метрики, шаблон `prometheus.yml.j2`

Ставится `Alertmanager` и подключаются правила алертов, шаблон `rules.yml.j2`

Ставится `Grafana` и добавляются дашборды, описаны в  `defaults\main.yml`

<details>
<summary>Вывод Ansible</summary>

```bash

user@user-ubuntu:~/devops/diplom/ansible$ ansible-playbook monitoring.yml -i hosts

PLAY [monitoring] ***************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : install python-firewall] *************************************************************************************************************************************
skipping: [monitoring.ovirt.ru] => (item=python-firewall) 

TASK [monitoring : Allow Ports] *************************************************************************************************************************************************
skipping: [monitoring.ovirt.ru] => (item=9090/tcp) 
skipping: [monitoring.ovirt.ru] => (item=9093/tcp) 
skipping: [monitoring.ovirt.ru] => (item=9094/tcp) 
skipping: [monitoring.ovirt.ru] => (item=9100/tcp) 
skipping: [monitoring.ovirt.ru] => (item=9094/udp) 

TASK [monitoring : Disable SELinux] *********************************************************************************************************************************************
skipping: [monitoring.ovirt.ru]

TASK [monitoring : Stop SELinux] ************************************************************************************************************************************************
skipping: [monitoring.ovirt.ru]

TASK [monitoring : Allow TCP Ports] *********************************************************************************************************************************************
ok: [monitoring.ovirt.ru] => (item=9090)
ok: [monitoring.ovirt.ru] => (item=9093)
ok: [monitoring.ovirt.ru] => (item=9094)
ok: [monitoring.ovirt.ru] => (item=9100)

TASK [monitoring : Allow UDP Ports] *********************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : Create the prometheus group] *********************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : Create User prometheus] **************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : Create directories for prometheus] ***************************************************************************************************************************
ok: [monitoring.ovirt.ru] => (item=/tmp/prometheus)
ok: [monitoring.ovirt.ru] => (item=/etc/prometheus)
ok: [monitoring.ovirt.ru] => (item=/var/lib/prometheus)

TASK [monitoring : Download And Unzipped Prometheus] ****************************************************************************************************************************
skipping: [monitoring.ovirt.ru]

TASK [monitoring : Copy Bin Files From Unzipped to Prometheus] ******************************************************************************************************************
ok: [monitoring.ovirt.ru] => (item=prometheus)
ok: [monitoring.ovirt.ru] => (item=promtool)

TASK [monitoring : Copy Conf Files From Unzipped to Prometheus] *****************************************************************************************************************
changed: [monitoring.ovirt.ru] => (item=console_libraries)
changed: [monitoring.ovirt.ru] => (item=consoles)

TASK [monitoring : Create File for Prometheus Systemd] **************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : copy config] *************************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : copy alert] **************************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : Systemctl Prometheus Start] **********************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : Create the alertmanager group] *******************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : Create User Alertmanager] ************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [monitoring : Create Directories For Alertmanager] *************************************************************************************************************************
changed: [monitoring.ovirt.ru] => (item=/tmp/alertmanager)
changed: [monitoring.ovirt.ru] => (item=/etc/alertmanager)
changed: [monitoring.ovirt.ru] => (item=/var/lib/prometheus/alertmanager)

TASK [monitoring : Download And Unzipped Alertmanager] **************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : Copy Bin Files From Unzipped to Alertmanager] ****************************************************************************************************************
changed: [monitoring.ovirt.ru] => (item=alertmanager)
changed: [monitoring.ovirt.ru] => (item=amtool)

TASK [monitoring : Copy Conf File From Unzipped to Alertmanager] ****************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : copy config] *************************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : Create File for Alertmanager Systemd] ************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [monitoring : Systemctl Alertmanager Start] ********************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Install dependencies] *******************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [grafana : Allow TCP Ports] ************************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Import Grafana Apt Key] *****************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Add APT Repository] *********************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Install Grafana on Debian Family] *******************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : start service grafana-server] ***********************************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : wait for service up] ********************************************************************************************************************************************
FAILED - RETRYING: [monitoring.ovirt.ru]: wait for service up (120 retries left).
FAILED - RETRYING: [monitoring.ovirt.ru]: wait for service up (119 retries left).
FAILED - RETRYING: [monitoring.ovirt.ru]: wait for service up (118 retries left).
ok: [monitoring.ovirt.ru]

TASK [grafana : change admin password for Grafana gui] **************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [grafana : Create/Update datasources file (provisioning)] ******************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Create local grafana dashboard directory] ***********************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [grafana : create grafana dashboards data directory] ***********************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : download grafana dashboard from grafana.net to local directory] *************************************************************************************************
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '3662', 'revision_id': '2', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '9578', 'revision_id': '4', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '9628', 'revision_id': '7', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '1860', 'revision_id': '27', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '4271', 'revision_id': '4', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '7362', 'revision_id': '5', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '2428', 'revision_id': '7', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '15211', 'revision_id': '1', 'datasource': 'Prometheus'})

TASK [grafana : Set the correct data source name in the dashboard] **************************************************************************************************************
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '3662', 'revision_id': '2', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '9578', 'revision_id': '4', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '9628', 'revision_id': '7', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '1860', 'revision_id': '27', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '4271', 'revision_id': '4', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '7362', 'revision_id': '5', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '2428', 'revision_id': '7', 'datasource': 'Prometheus'})
ok: [monitoring.ovirt.ru] => (item={'dashboard_id': '15211', 'revision_id': '1', 'datasource': 'Prometheus'})

TASK [grafana : Create/Update dashboards file (provisioning)] *******************************************************************************************************************
changed: [monitoring.ovirt.ru]

TASK [grafana : Register previously copied dashboards] **************************************************************************************************************************
skipping: [monitoring.ovirt.ru]

TASK [grafana : Register dashboards to copy] ************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

TASK [grafana : Import grafana dashboards] **************************************************************************************************************************************
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/9578.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 307942, 'inode': 400382, 'dev': 64514, 'nlink': 1, 'atime': 1662763957.9240286, 'mtime': 1662763947.9880037, 'ctime': 1662763947.9880037, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/4271.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 33577, 'inode': 400384, 'dev': 64514, 'nlink': 1, 'atime': 1662763960.7280357, 'mtime': 1662763960.7280357, 'ctime': 1662763960.7280357, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/9628.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 71832, 'inode': 400381, 'dev': 64514, 'nlink': 1, 'atime': 1662763958.860031, 'mtime': 1662763958.860031, 'ctime': 1662763958.860031, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/3662.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 85558, 'inode': 400389, 'dev': 64514, 'nlink': 1, 'atime': 1662763956.972026, 'mtime': 1662763956.972026, 'ctime': 1662763956.972026, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/1860.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 387696, 'inode': 400383, 'dev': 64514, 'nlink': 1, 'atime': 1662763959.7920332, 'mtime': 1662763959.7920332, 'ctime': 1662763959.7920332, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/7362.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 129775, 'inode': 400385, 'dev': 64514, 'nlink': 1, 'atime': 1662763962.7360406, 'mtime': 1662763962.7360406, 'ctime': 1662763962.7360406, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/15211.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 78766, 'inode': 400388, 'dev': 64514, 'nlink': 1, 'atime': 1662763964.7080455, 'mtime': 1662763955.712023, 'ctime': 1662763955.712023, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})
changed: [monitoring.ovirt.ru] => (item={'path': '/tmp/ansible.5_jq0h_0/2428.json', 'mode': '0644', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 0, 'gid': 0, 'size': 122985, 'inode': 400386, 'dev': 64514, 'nlink': 1, 'atime': 1662763963.7240431, 'mtime': 1662763963.7240431, 'ctime': 1662763963.7240431, 'gr_name': 'root', 'pw_name': 'root', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': True, 'xgrp': False, 'woth': False, 'roth': True, 'xoth': False, 'isuid': False, 'isgid': False})

TASK [grafana : Get dashboard lists] ********************************************************************************************************************************************
skipping: [monitoring.ovirt.ru]

TASK [grafana : Remove dashboards not present on deployer machine (synchronize)] ************************************************************************************************
skipping: [monitoring.ovirt.ru]

RUNNING HANDLER [monitoring : restart prometheus] *******************************************************************************************************************************
changed: [monitoring.ovirt.ru]

RUNNING HANDLER [monitoring : restart alertmanager] *****************************************************************************************************************************
changed: [monitoring.ovirt.ru]

RUNNING HANDLER [grafana : grafana systemd] *************************************************************************************************************************************
ok: [monitoring.ovirt.ru]

RUNNING HANDLER [grafana : restart grafana] *************************************************************************************************************************************
changed: [monitoring.ovirt.ru]

RUNNING HANDLER [grafana : Set privileges on provisioned dashboards] ************************************************************************************************************
changed: [monitoring.ovirt.ru]

RUNNING HANDLER [grafana : Set privileges on provisioned dashboards directory] **************************************************************************************************
changed: [monitoring.ovirt.ru]

PLAY RECAP **********************************************************************************************************************************************************************
monitoring.ovirt.ru        : ok=43   changed=26   unreachable=0    failed=0    skipped=8    rescued=0    ignored=0

```

</details>

Что мы получаем: 

`Prometheus`, доступен по адресу `https://prometheus.ovirt.ru/`

![39](img/img039.PNG)

![40](img/img040.PNG)

`Alertmanager`, доступен по адресу `https://alertmanager.ovirt.ru/`

![41](img/img041.PNG)

`Grafana`, доступен по адресу `https://grafana.ovirt.ru/`

![42](img/img042.PNG)

Дашборды

![43](img/img043.PNG)

Дашборд отображающий метрики из Node Exporter по всем серверам

![44](img/img044.PNG)

Для проверки `Alertmanager`, погасим один из серверов, допустим `runner`

![45](img/img045.PNG)

Проверим `Prometheus`

![46](img/img046.PNG)

![47](img/img047.PNG)

Проверим `Alertmanager`

![48](img/img048.PNG)

И `Grafana`

![49](img/img049.PNG)

Видим что везде тревога есть.

---

---
## Что необходимо для сдачи задания?

1. Репозиторий со всеми Terraform манифестами и готовность продемонстрировать создание всех ресурсов с нуля.
2. Репозиторий со всеми Ansible ролями и готовность продемонстрировать установку всех сервисов с нуля.
3. Скриншоты веб-интерфейсов всех сервисов работающих по HTTPS на вашем доменном имени.
  - `https://www.you.domain` (WordPress)
  - `https://gitlab.you.domain` (Gitlab)
  - `https://grafana.you.domain` (Grafana)
  - `https://prometheus.you.domain` (Prometheus)
  - `https://alertmanager.you.domain` (Alert Manager)
4. Все репозитории рекомендуется хранить на одном из ресурсов ([github.com](https://github.com) или [gitlab.com](https://gitlab.com)).

---

Выполненная работа:

Манифесты [Terraform](scripts/terraform)

Роли [Ansible](scripts/ansible)

Работа по `https`

![50](img/img050.PNG)

`https://www.ovirt.ru` (WordPress)

![51](img/img051.PNG)

`https://gitlab.ovirt.ru` (Gitlab)

![52](img/img052.PNG)

`https://grafana.ovirt.ru` (Grafana)

![53](img/img053.PNG)

`https://prometheus.ovirt.ru` (Prometheus)

![54](img/img054.PNG)

`https://alertmanager.ovirt.ru` (Alert Manager)

![55](img/img055.PNG)

---

---
## Как правильно задавать вопросы дипломному руководителю?

**Что поможет решить большинство частых проблем:**

1. Попробовать найти ответ сначала самостоятельно в интернете или в
  материалах курса и ДЗ и только после этого спрашивать у дипломного
  руководителя. Навык поиска ответов пригодится вам в профессиональной
  деятельности.
2. Если вопросов больше одного, то присылайте их в виде нумерованного
  списка. Так дипломному руководителю будет проще отвечать на каждый из
  них.
3. При необходимости прикрепите к вопросу скриншоты и стрелочкой
  покажите, где не получается.

**Что может стать источником проблем:**

1. Вопросы вида «Ничего не работает. Не запускается. Всё сломалось». Дипломный руководитель не сможет ответить на такой вопрос без дополнительных уточнений. Цените своё время и время других.
2. Откладывание выполнения курсового проекта на последний момент.
3. Ожидание моментального ответа на свой вопрос. Дипломные руководители работающие разработчики, которые занимаются, кроме преподавания, своими проектами. Их время ограничено, поэтому постарайтесь задавать правильные вопросы, чтобы получать быстрые ответы :)
