import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ClaveModule", (m) => {

  // TODO: Set addresses for the contract arguments below
  const clave = m.contract("Clave", [defaultAdmin, minter]);

  return { clave };
});
