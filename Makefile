base:
	docker build --tag=alpine-java:base --rm=true -f Dockerfile.base .

build:
	gradle bootRepackage

package: build
	docker build --tag=slackbot:latest .


all: base build package


deploy:
	docker stack deploy mongo -c stack.yml
