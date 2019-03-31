FROM alpine-java:base
MAINTAINER steve@whitesquaresoft.com
COPY build/libs/spring-boot-slackbot-example-0.0.1-SNAPSHOT.jar /opt/spring-cloud/lib/
ENTRYPOINT ["/usr/bin/java"]
CMD ["-jar", "/opt/spring-cloud/lib/spring-boot-slackbot-example-0.0.1-SNAPSHOT.jar"]
VOLUME /var/lib/spring-cloud/config-repo
EXPOSE 8888