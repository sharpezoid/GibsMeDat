import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import React from 'react';
import App from './App';

test('renders main heading', () => {
  render(<App />);
  expect(
    screen.getByRole('heading', {
      level: 1,
      name: /\$GIBS – From each according to their bags, to each according to their memes./i,
    })
  ).toBeInTheDocument();
});
