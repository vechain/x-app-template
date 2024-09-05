import FingerprintJS from "@fingerprintjs/fingerprintjs";
import { DeviceUUID } from "device-uuid";

/**
 * Generates a device ID using the FingerprintJS library and the device-uuid library
 * @returns {Promise<string>} The generated device ID
 */
export const getDeviceId = async () => {
  // Load the FingerprintJS agent
  const fp = await FingerprintJS.load();

  // Get the visitor identifier
  const result = await fp.get();

  const uuid = new DeviceUUID().get();

  // Use the fingerprint's visitorId as the device ID and append the deviceUUID
  // This diminuishes the chance of collisions by combining two different methods of generating a device ID
  const deviceID = result.visitorId + uuid;

  return deviceID;
};
