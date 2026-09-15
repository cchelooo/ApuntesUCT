import type { Career } from '../../domain/catalog/career';
export const careersMock: Career[] = [
  {
    id: 'c1',
    universityId: 'u1',
    name: 'Ingeniería Civil Informática',
    code: 'ICINF',
    active: true,
  },
  {
    id: 'c2',
    universityId: 'u1',
    name: 'Ingeniería Civil Industrial',
    code: 'ICIND',
    active: true,
  },
  {
    id: 'c3',
    universityId: 'u1',
    name: 'Pedagogía en Educación Básica',
    code: 'PEDB',
    active: true,
  },
  { id: 'c4', universityId: 'u1', name: 'Enfermería', code: 'ENF', active: true },
  {
    id: 'c5',
    universityId: 'u2',
    name: 'Ingeniería Civil en Informática',
    code: 'ICI',
    active: true,
  },
  { id: 'c6', universityId: 'u2', name: 'Medicina', code: 'MED', active: true },
];