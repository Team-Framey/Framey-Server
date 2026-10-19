package framey.collage;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@ConfigurationPropertiesScan
@SpringBootApplication
public class CollageServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(CollageServiceApplication.class, args);
    }
}
