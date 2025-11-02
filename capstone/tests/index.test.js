import { someFunction } from '../src/index';
import { helperFunction } from '../src/utils/helpers';

describe('Application Tests', () => {
    test('should return expected output from someFunction', () => {
        const input = 'test input';
        const expectedOutput = 'expected output';
        expect(someFunction(input)).toBe(expectedOutput);
    });

    test('should correctly use helperFunction', () => {
        const input = 'helper input';
        const expectedOutput = 'helper output';
        expect(helperFunction(input)).toBe(expectedOutput);
    });
});