package com.socialworld.auth;

import com.socialworld.auth.AuthModels.LoginRequest;
import com.socialworld.auth.AuthModels.LogoutRequest;
import com.socialworld.auth.AuthModels.RefreshRequest;
import com.socialworld.auth.AuthModels.RegisterRequest;
import com.socialworld.auth.AuthModels.TokenResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

import static com.socialworld.auth.AuthModels.PublicUser;

@RestController
@RequestMapping("/api/v1/auth")
class AuthController {
    private final AuthenticationService authentication;

    AuthController(AuthenticationService authentication) { this.authentication = authentication; }

    @PostMapping("/register")
    ResponseEntity<PublicUser> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authentication.register(request));
    }

    @PostMapping("/login")
    TokenResponse login(@Valid @RequestBody LoginRequest request) { return authentication.login(request); }

    @PostMapping("/refresh")
    TokenResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authentication.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    ResponseEntity<Void> logout(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody LogoutRequest request) {
        authentication.logout(UUID.fromString(jwt.getSubject()), request.refreshToken());
        return ResponseEntity.noContent().build();
    }
}
