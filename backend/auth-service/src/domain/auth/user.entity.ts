import { Role } from './role.enum';

export interface User {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  role: Role;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}
