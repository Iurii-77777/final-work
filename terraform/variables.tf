# Заменить на ID своего облака
# https://console.cloud.yandex.ru/cloud?section=overview
variable "yandex_cloud_id" {
  default = "b1gp9k6jt4bbkkfr2vup"
}

# Заменить на Folder своего облака
# https://console.cloud.yandex.ru/cloud?section=overview
variable "yandex_folder_id" {
  default = "b1gi8uu2eq7nih1vp6dq"
}

# Заменить на ID своего образа
# ID можно узнать с помощью команды yc compute image list
variable "centos-7-base" {
  default = "fd80q5979r924k9hjo7t"
}

# Заменить на ID своего сервисного аккаунта
variable "service_account_id" {
  default = "ajeph504a9mb61sdit7d"
}

variable "lan_proxy_ip" {
  default = "192.168.101.100"
}

variable "ubuntu18" {
  default = "fd8v7ru46kt3s4o5f0uo"
}

variable "ubuntu20" {
  default = "fd8kdq6d0p8sij7h5qe3"
}

variable "ubuntu22" {
  default = "fd8autg36kchufhej85b"
}