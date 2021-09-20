variable "tag_prefix" {
  description = "resource name prefix"
  type        = string
  # default     = "tf"
}

variable "az_list" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "az_num_list" {
  type    = list(string)
  default = ["1a", "1c", "1d"]
}


variable "resource_cnt" {
  type    = number
  default = 2
}

variable "ec2_conf" {
  type = map(string)
  default = {
    ami           = "ami-02892a4ea9bfa2192"
    instance_type = "t2.micro"
    key_pair      = "common_key"
  }

}

