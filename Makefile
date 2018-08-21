TMP_TAG=tmp-drone-kubernetes-tag

tag:
	test -n "$(tag)" # Must specify a tag! - e.g. tag=somebody/drone-kubernetes

build:
	docker build -t $(TMP_TAG) .

push: tag build
	docker tag $(TMP_TAG) $(tag)
	docker push $(tag)

test:
	docker-compose build
	docker-compose run --rm plugin
