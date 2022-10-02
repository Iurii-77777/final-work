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
}

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
}