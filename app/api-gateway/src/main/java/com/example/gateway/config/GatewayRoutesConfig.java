package com.example.gateway.config;

import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GatewayRoutesConfig {

    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
        return builder.routes()
                .route("user-service", r -> r
                        .path("/api/users/**")
                        .uri("http://user-service:8081"))
                .route("order-service", r -> r
                        .path("/api/orders/**")
                        .uri("http://order-service:8082"))
                .route("user-service-health", r -> r
                        .path("/api/users/health")
                        .uri("http://user-service:8081"))
                .route("order-service-health", r -> r
                        .path("/api/orders/health")
                        .uri("http://order-service:8082"))
                .build();
    }
}
