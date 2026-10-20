package com.socialworld.auth;

public final class AuthExceptions {
    private AuthExceptions() {}

    public static class EmailAlreadyRegistered extends RuntimeException {}
    public static class InvalidCredentials extends RuntimeException {}
    public static class InvalidRefreshToken extends RuntimeException {}
    public static class AccountUnavailable extends RuntimeException {}
    public static class InvalidRequest extends RuntimeException {
        public InvalidRequest(String message) { super(message); }
    }
}
