package framey.common.config;

import framey.common.aspect.LogActivityAspect;
import framey.common.filter.TraceIdFilter;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
public class MonitoringAutoConfiguration {

    @Bean
    public TraceIdFilter traceIdFilter() {
        return new TraceIdFilter();
    }

    @Bean
    public LogActivityAspect logActivityAspect() {
        return new LogActivityAspect();
    }
}
