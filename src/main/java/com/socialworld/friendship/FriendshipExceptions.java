package com.socialworld.friendship;

public final class FriendshipExceptions {
    private FriendshipExceptions() {}

    public static class FriendCodeNotFound extends RuntimeException {}
    public static class SelfRequest extends RuntimeException {}
    public static class RequestPending extends RuntimeException {}
    public static class AlreadyFriends extends RuntimeException {}
    public static class RequestNotFound extends RuntimeException {}
    public static class InvalidTransition extends RuntimeException {}
    public static class WrongRequestActor extends RuntimeException {}
    public static class FriendshipNotFound extends RuntimeException {}
}
