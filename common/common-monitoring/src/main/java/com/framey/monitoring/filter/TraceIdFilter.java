package com.framey.monitoring.filter;

import java.io.IOException;
import java.util.UUID;

import org.springframework.web.filter.OncePerRequestFilter;

import org.slf4j.MDC;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class TraceIdFilter extends OncePerRequestFilter {

	public static final String TRACE_ID = "traceId";
	public static final String TRACE_ID_HEADER = "X-Trace-Id";

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain
	) throws ServletException, IOException {
		String traceId = UUID.randomUUID()
				.toString()
				.replace("-", "")
				.substring(0, 8);

		MDC.put(TRACE_ID, traceId);
		response.setHeader(TRACE_ID_HEADER, traceId);

		try {
			filterChain.doFilter(request, response);
		} finally {
			MDC.remove(TRACE_ID);
		}
	}
}