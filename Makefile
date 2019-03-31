base:
	docker build --tag=alpine-java:base --rm=true -f Dockerfile.base .

run:
	gradle bootRun

build:
	gradle bootRepackage

package: build
	docker build --tag=slackbot:latest .


all: base build package


deploy:
	docker stack deploy slackbot -c stack.yml

ls:
	docker stack ps slackbot

delete:
	docker stack rm slackbot
