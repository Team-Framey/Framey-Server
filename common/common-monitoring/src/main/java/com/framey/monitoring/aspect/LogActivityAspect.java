package com.framey.monitoring.aspect;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;

import com.framey.monitoring.annotation.LogActivity;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@Aspect
public class LogActivityAspect {

	@Around("@annotation(logActivity)")
	public Object logActivity(ProceedingJoinPoint joinPoint, LogActivity logActivity) throws Throwable {
		String activity = logActivity.value();
		long start = System.currentTimeMillis();

		log.info("[START] {}", activity);

		try {
			Object result = joinPoint.proceed();

			long elapsed = System.currentTimeMillis() - start;
			log.info("[SUCCESS] {} | elapsed={}ms", activity, elapsed);

			return result;
		} catch (Throwable e) {
			long elapsed = System.currentTimeMillis() - start;

			log.error("[FAIL] {} | elapsed={}ms", activity, elapsed, e);
			throw e;
		}
	}
}