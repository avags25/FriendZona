package com.socialworld.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.http.converter.HttpMessageNotReadableException;

@RestControllerAdvice
class ApiExceptionHandler {
    @ExceptionHandler(AuthExceptions.EmailAlreadyRegistered.class)
    ProblemDetail emailConflict() {
        return problem(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED", "An account with this email already exists");
    }

    @ExceptionHandler(AuthExceptions.InvalidCredentials.class)
    ProblemDetail invalidCredentials() {
        return problem(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Email or password is incorrect");
    }

    @ExceptionHandler(AuthExceptions.InvalidRefreshToken.class)
    ProblemDetail invalidRefreshToken() {
        return problem(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Refresh token is invalid or expired");
    }

    @ExceptionHandler(AuthExceptions.AccountUnavailable.class)
    ProblemDetail unavailableAccount() {
        return problem(HttpStatus.UNAUTHORIZED, "ACCOUNT_UNAVAILABLE", "The account is unavailable");
    }

    @ExceptionHandler(AuthExceptions.InvalidRequest.class)
    ProblemDetail invalidRequest(AuthExceptions.InvalidRequest exception) {
        return problem(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", exception.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail invalidFields() {
        return problem(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "One or more request fields are invalid");
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ProblemDetail malformedJson() {
        return problem(HttpStatus.BAD_REQUEST, "MALFORMED_REQUEST", "Request body is invalid");
    }

    @ExceptionHandler(Exception.class)
    ProblemDetail unexpectedError() {
        return problem(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "An unexpected error occurred");
    }

    private static ProblemDetail problem(HttpStatus status, String code, String detail) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
        problem.setProperty("code", code);
        return problem;
    }
}
