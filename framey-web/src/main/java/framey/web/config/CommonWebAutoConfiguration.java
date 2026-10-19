package framey.web.config;

import framey.web.advice.CommonExceptionHandler;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Import;

@AutoConfiguration
@Import(CommonExceptionHandler.class)
public class CommonWebAutoConfiguration {
}
