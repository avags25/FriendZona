package com.socialworld.friendship;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;

@Component
public class FriendCodeGenerator {
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private final SecureRandom random = new SecureRandom();

    public String generate() {
        var code = new StringBuilder("SW-");
        for (int index = 0; index < 10; index++) {
            code.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return code.toString();
    }
}
