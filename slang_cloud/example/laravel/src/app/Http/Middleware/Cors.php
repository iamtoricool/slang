<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class Cors
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('Access-Control-Allow-Origin', '*');
        $response->headers->set('Access-Control-Allow-Methods', 'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS');
        $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, X-Translation-Hash');
        $response->headers->set('Access-Control-Expose-Headers', 'X-Translation-Hash');

        if ($request->getMethod() === 'OPTIONS') {
            $response->setStatusCode(204);
        }

        return $response;
    }
}
