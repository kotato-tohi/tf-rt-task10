variable "tag_prefix" {
  description = "resource name prefix"
  type        = string
  default     = "tf"
}

variable "az_list" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "az_num_list" {
  type    = list(string)
  default = ["1a", "1c", "1d"]
}