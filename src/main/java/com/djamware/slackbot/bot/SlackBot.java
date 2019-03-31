/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.djamware.slackbot.bot;

import com.djamware.slackbot.models.BadWord;
import com.djamware.slackbot.repositories.BadwordRepository;
import java.util.Arrays;
import java.util.regex.Matcher;

import io.micrometer.core.annotation.Timed;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Metrics;
import me.ramswaroop.jbot.core.slack.Bot;
import me.ramswaroop.jbot.core.slack.Controller;
import me.ramswaroop.jbot.core.slack.EventType;
import me.ramswaroop.jbot.core.slack.models.Event;
import me.ramswaroop.jbot.core.slack.models.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

/**
 *
 * @author didin
 */
@Component
public class SlackBot extends Bot {
    
    @Autowired
    BadwordRepository badwordRepository;

    private static final Logger logger = LoggerFactory.getLogger(SlackBot.class);

    private Counter dmCounter = Metrics.counter("slack_dm", "region", "test");
    private Counter messageCounter = Metrics.counter("slack_message", "region", "test");

    @Value("${slackBotToken}")
    private String slackToken;

    @Override
    public String getSlackToken() {
        return slackToken;
    }

    @Override
    public Bot getSlackBot() {
        return this;
    }

    @Timed(value="blart")
    @Controller(events = {EventType.DIRECT_MENTION, EventType.DIRECT_MESSAGE})
    public void onReceiveDM(WebSocketSession session, Event event) {
        logger.info("Recieved " + event.getText());
        dmCounter.increment();
        reply(session, event, new Message("Hi, I am " + slackService.getCurrentUser().getName()));
    }
    
    @Controller(events = EventType.MESSAGE, pattern = "fuck|shit|bitch")
    public void onReceiveMessage(WebSocketSession session, Event event, Matcher matcher) {
        messageCounter.increment();
        if(!matcher.group(0).isEmpty()) {
//            BadWord badword = new BadWord(event.getUserId(), matcher.group(0));
//            badwordRepository.save(badword);
            Integer countBadWords = 3; //badwordRepository.countByUser(event.getUserId());
            if(countBadWords >= 5) {
                reply(session, event, new Message("Enough! You have too many say bad words. \nThe admin will kick you away from this channel."));
            } else {
                reply(session, event, new Message("Becareful you have said bad words "+countBadWords+" times"));
            }
        }
    }
}
