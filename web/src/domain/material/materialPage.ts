import type { MaterialListItem } from './materialListItem';

export interface MaterialPage {
  items: MaterialListItem[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}
