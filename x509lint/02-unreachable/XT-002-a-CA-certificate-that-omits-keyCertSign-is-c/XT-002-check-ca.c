/* XT-002 — does X509_check_ca() call a CA:TRUE certificate a CA when its
* keyUsage omits keyCertSign? Executed, not read. * *     cc -o check-ca XT-002-check-ca.c -lcrypto *     ./check-ca positive/XT-002-ca-without-keycertsign.pem positive/XT-002-ca-with-keycertsign.pem */
# include <stdio.h> include <string.h> include <openssl/x509v3.h> include
# <openssl/pem.h>

static const char *base(const char *p)
{
	const char *s = strrchr(p, '/');
	return s ? s + 1 : p;
}

int main(int argc, char **argv)
{
	for (int i = 1; i < argc; i++) {
		FILE *f = fopen(argv[i], "r");
		if (f == NULL) {
			printf("%-34s  cannot open\n", base(argv[i]));
			continue;
		}
		X509 *x = PEM_read_X509(f, NULL, NULL, NULL);
		fclose(f);
		if (x == NULL) {
			printf("%-34s  not a PEM certificate\n", base(argv[i]));
			continue;
		}
		BASIC_CONSTRAINTS *bc =
			X509_get_ext_d2i(x, NID_basic_constraints, NULL, NULL);
		uint32_t ku = X509_get_key_usage(x);
		printf("%-34s  bc.CA=%-5s keyCertSign=%-4s X509_check_ca()=%d\n",
		       base(argv[i]),
		       bc != NULL && bc->ca ? "TRUE" : "false",
		       (ku & KU_KEY_CERT_SIGN) ? "yes" : "no",
		       X509_check_ca(x));
		if (bc != NULL)
			BASIC_CONSTRAINTS_free(bc);
		X509_free(x);
	}
	return 0;
}
