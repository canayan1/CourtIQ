// Verifies a StoreKit 2 transaction the app sends as its JWS representation.
//
// Offline: Apple's library checks the certificate chain in the JWS header
// against Apple's Root CA G3 (embedded below — it is a public certificate,
// valid to 2039), then the signature, then that the payload names OUR bundle
// id and the environment we expect. No network, no App Store Connect key.
//
// Why this exists: the order function used to store the transaction id the
// client claimed and create the order for any signed-in user. A coach's
// time is the cost of trusting that.

import { Buffer } from "node:buffer";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@3.1.0";

const BUNDLE_ID = "com.canayan93.courtiq";
const APP_APPLE_ID = 6773753464;
// https://www.apple.com/certificateauthority/AppleRootCA-G3.cer (DER, base64)
const APPLE_ROOT_CA_G3_B64 = "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";

export type VerifiedPurchase = {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  environment: "Production" | "Sandbox";
  purchaseDate: number;
};

function verifier(env: Environment): SignedDataVerifier {
  return new SignedDataVerifier(
    [Buffer.from(APPLE_ROOT_CA_G3_B64, "base64")],
    false,               // no online revocation checks — offline is the point
    env,
    BUNDLE_ID,
    APP_APPLE_ID,
  );
}

/**
 * Returns the verified purchase, or a short reason string. Production is
 * always tried first; Sandbox only when the caller allows it (the owner's
 * device test), so a sandbox receipt can never buy a production review by
 * accident.
 */
export async function verifyCoachReviewPurchase(
  jws: string,
  expectedProductId: string,
  allowSandbox: boolean,
): Promise<VerifiedPurchase | { error: string }> {
  const attempts: Array<[Environment, "Production" | "Sandbox"]> = [[Environment.PRODUCTION, "Production"]];
  if (allowSandbox) attempts.push([Environment.SANDBOX, "Sandbox"]);

  let lastError = "unverified";
  for (const [env, label] of attempts) {
    try {
      const tx = await verifier(env).verifyAndDecodeTransaction(jws);
      if (tx.productId !== expectedProductId) return { error: "wrong-product" };
      if (tx.revocationDate) return { error: "revoked" };
      if (tx.type && tx.type !== "Consumable") return { error: "wrong-type" };
      return {
        transactionId: String(tx.transactionId),
        originalTransactionId: String(tx.originalTransactionId ?? tx.transactionId),
        productId: tx.productId ?? expectedProductId,
        environment: label,
        purchaseDate: Number(tx.purchaseDate ?? 0),
      };
    } catch (e) {
      lastError = (e as Error)?.constructor?.name ?? "unverified";
    }
  }
  return { error: lastError };
}
