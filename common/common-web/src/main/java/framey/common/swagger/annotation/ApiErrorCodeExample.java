package framey.common.swagger.annotation;

import framey.common.response.ErrorCode;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ApiErrorCodeExample {

    Class<? extends ErrorCode>[] value();

    String[] include() default {};
}
