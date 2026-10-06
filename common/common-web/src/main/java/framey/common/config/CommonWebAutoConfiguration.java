package framey.common.config;

import framey.common.advice.CommonExceptionHandler;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Import;

@AutoConfiguration
@Import(CommonExceptionHandler.class)
public class CommonWebAutoConfiguration {
}
