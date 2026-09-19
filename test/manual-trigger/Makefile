SHELL := /usr/bin/env bash

.PHONY: init plan apply destroy show clean zip

zip:
	mkdir -p _bundle_tmp
	echo "module.exports = async () => ({ statusCode: 200, body: 'ok' });" > _bundle_tmp/index.js
	(cd _bundle_tmp && zip -q ../function.zip index.js)
	rm -rf _bundle_tmp

init: zip
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
