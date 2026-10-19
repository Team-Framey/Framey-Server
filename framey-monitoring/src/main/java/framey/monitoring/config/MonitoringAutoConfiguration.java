package framey.monitoring.config;

import framey.monitoring.aspect.LogActivityAspect;
import framey.monitoring.filter.TraceIdFilter;
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
