SHELL := /usr/bin/env bash

.PHONY: init plan apply destroy show clean

init:
	terraform init

plan: init
	terraform plan -out=tfplan

apply:
	terraform apply -auto-approve tfplan

destroy:
	terraform destroy -auto-approve

show:
	terraform show -no-color

clean:
	rm -rf .terraform terraform.tfstate terraform.tfstate.backup tfplan
