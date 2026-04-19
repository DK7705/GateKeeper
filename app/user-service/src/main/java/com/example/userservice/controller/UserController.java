package com.example.userservice.controller;

import com.example.userservice.model.User;
import com.example.userservice.repository.UserRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.File;
import java.io.StringReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private static final Logger logger = LoggerFactory.getLogger(UserController.class);

    @Autowired
    private UserRepository userRepository;

    @PersistenceContext
    private EntityManager entityManager;

    @GetMapping
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<User> getUserById(@PathVariable Long id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<User> createUser(@RequestBody User user) {
        User savedUser = userRepository.save(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(savedUser);
    }

    // =========================================================================
    // SEEDED VULNERABILITY #1: SQL Injection
    // Parameterised query bypass — user input concatenated directly into SQL
    // SonarQube SAST MUST detect this as Critical/Blocker severity
    // =========================================================================
    @GetMapping("/search")
    public ResponseEntity<?> searchUsers(@RequestParam String username) {
        logger.info("Searching for user: {}", username);
        String sql = "SELECT u FROM User u WHERE u.username = '" + username + "'";
        Query query = entityManager.createQuery(sql);
        List<?> results = query.getResultList();
        return ResponseEntity.ok(results);
    }

    // =========================================================================
    // SEEDED VULNERABILITY #2: Path Traversal in File Upload
    // User-controlled filename used directly in file path without sanitization
    // SonarQube SAST MUST detect this as Critical severity
    // =========================================================================
    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(
            @RequestParam("file") MultipartFile file,
            @RequestParam("filename") String filename) {
        try {
            String uploadDir = "/app/uploads/";
            Path filePath = Paths.get(uploadDir + filename);
            Files.createDirectories(filePath.getParent());
            Files.write(filePath, file.getBytes());
            logger.info("File uploaded to: {}", filePath);
            return ResponseEntity.ok(Map.of("message", "File uploaded successfully", "path", filePath.toString()));
        } catch (Exception e) {
            logger.error("File upload failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Upload failed: " + e.getMessage()));
        }
    }

    // =========================================================================
    // SEEDED VULNERABILITY #3: XXE (XML External Entity) Injection
    // XML parser configured without disabling external entities
    // SonarQube SAST MUST detect this as Blocker severity
    // =========================================================================
    @PostMapping("/import")
    public ResponseEntity<Map<String, String>> importUsersFromXml(@RequestBody String xmlData) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            org.w3c.dom.Document document = builder.parse(new InputSource(new StringReader(xmlData)));

            String rootElement = document.getDocumentElement().getNodeName();
            int userCount = document.getElementsByTagName("user").getLength();

            logger.info("Imported {} users from XML", userCount);
            return ResponseEntity.ok(Map.of(
                    "message", "XML import completed",
                    "rootElement", rootElement,
                    "usersImported", String.valueOf(userCount)
            ));
        } catch (Exception e) {
            logger.error("XML import failed", e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "XML parsing failed: " + e.getMessage()));
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "UP",
                "service", "user-service",
                "version", "1.0.0"
        ));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

    @PutMapping("/{id}")
    public ResponseEntity<User> updateUser(@PathVariable Long id, @RequestBody User userDetails) {
        Optional<User> optionalUser = userRepository.findById(id);
        if (optionalUser.isPresent()) {
            User user = optionalUser.get();
            user.setUsername(userDetails.getUsername());
            user.setEmail(userDetails.getEmail());
            user.setFullName(userDetails.getFullName());
            user.setRole(userDetails.getRole());
            return ResponseEntity.ok(userRepository.save(user));
        }
        return ResponseEntity.notFound().build();
    }
}
