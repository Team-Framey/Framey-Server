package framey.archive;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@ConfigurationPropertiesScan
@SpringBootApplication
public class ArchiveServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(ArchiveServiceApplication.class, args);
    }

}
